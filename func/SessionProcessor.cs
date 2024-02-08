using System;
using System.Collections.Generic;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.Azure.WebJobs.Extensions.Sql;
using System.Net.Http;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Net;
using Dapper;
using System.Security.Cryptography;
using System.Linq;
using Microsoft.SqlServer.TransactSql.ScriptDom;

namespace SessionRecommender.SessionProcessor
{
    public class Item 
    {
        public int Id { get; set; }

        [JsonProperty("require_embeddings_update")]
        public bool RequireEmbeddingsUpdate { get; set; }

        public override bool Equals(object obj)
        {
            if (obj is Item)
            {
                var that = obj as Item;
                return Id == that.Id;
            }
            return false;
        }

        public override int GetHashCode()
        {
            return Id.GetHashCode();
        }

        public override string ToString()
        {
            return Id.ToString();
        }
    }

    public class Session: Item
    {
        public string Title { get; set; }

        public string Abstract { get; set; }       

        public override bool Equals(object obj)
        {
            if (obj is Session)
            {
                var that = obj as Session;
                return Id == that.Id && Title == that.Title && Abstract == that.Abstract;
            }
            return false;
        }

        public override int GetHashCode()
        {
            return Id.GetHashCode() ^ Title.GetHashCode() ^ Abstract.GetHashCode();
        }

        public override string ToString()
        {
            return Id.ToString();
        }
    }

    public class Speaker: Item
    {
        [JsonProperty("full_name")]
        public string FullName { get; set; }

        public string Abstract { get; set; }

        public override bool Equals(object obj)
        {
            if (obj is Speaker)
            {
                var that = obj as Speaker;
                return Id == that.Id && FullName == that.FullName;
            }
            return false;
        }

        public override int GetHashCode()
        {
            return Id.GetHashCode() ^ FullName.GetHashCode() ^ Abstract.GetHashCode();
        }

        public override string ToString()
        {
            return Id.ToString();
        }
    }

    public class ChangedItem: Item 
    {
        public SqlChangeOperation Operation { get; set; }        
        public string Payload { get; set; }
    }


    public static class SessionProcessor
    {
        private static readonly HttpClient httpClient;

        static SessionProcessor()
        {
            var key = Environment.GetEnvironmentVariable("AZURE_OPENAI_KEY");
            var endpoint = Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT");

            httpClient = new HttpClient
            {
                BaseAddress = new Uri(endpoint)
            };
            httpClient.DefaultRequestHeaders.Add("api-key", key);
        }

        [FunctionName(nameof(SessionTrigger))]
        public static async Task SessionTrigger(
            [SqlTrigger("[web].[sessions]", "AZURE_SQL_CONNECTION_STRING")]
            IReadOnlyList<SqlChange<Session>> changes,
            ILogger logger)
        {
            logger.LogInformation("Detected: " + changes.Count + " changes on session table.");

            var ci = from c in changes 
                        where c.Operation != SqlChangeOperation.Delete 
                        where c.Item.RequireEmbeddingsUpdate == true
                        select new ChangedItem() { 
                            Id = c.Item.Id, 
                            Operation = c.Operation, 
                            Payload = c.Item.Title + ':' + c.Item.Abstract 
                        };

            await ProcessChanges(ci, "web.sessions", "web.upsert_session_embeddings", logger);
        }

        [FunctionName(nameof(SpeakerTrigger))]
        public static async Task SpeakerTrigger(
            [SqlTrigger("[web].[speakers]", "AZURE_SQL_CONNECTION_STRING")]
            IReadOnlyList<SqlChange<Speaker>> changes,
            ILogger logger)
        {
            logger.LogInformation("Detected: " + changes.Count + " changes on speakers table.");
                    
            var ci = from c in changes 
                        where c.Operation != SqlChangeOperation.Delete 
                        where c.Item.RequireEmbeddingsUpdate == true
                        select new ChangedItem() { 
                            Id = c.Item.Id, 
                            Operation = c.Operation, 
                            Payload = c.Item.FullName 
                        };

            await ProcessChanges(ci, "web.speakers", "web.upsert_speaker_embeddings", logger);          
        }

        private static async Task ProcessChanges(IEnumerable<ChangedItem> changes, string referenceTable, string upsertStoredProcedure, ILogger logger)
        {
            logger.LogInformation($"Processing {changes.Count()} changes on table {referenceTable}.");

            foreach (var change in changes)
            {
                logger.LogInformation($"[{referenceTable}:{change.Id}] Processing change for operation: " + change.Operation.ToString());

                var attempts = 0;
                var embeddingsReceived = false;
                while (attempts < 3)
                {
                    attempts++;

                    logger.LogInformation($"[{referenceTable}:{change.Id}] Attempt {attempts}/3 to get embeddings.");

                    var deploymentName = Environment.GetEnvironmentVariable("AZURE_OPENAI_DEPLOYMENT_NAME");
                    var requestUri = "/openai/deployments/" + deploymentName + "/embeddings?api-version=2023-03-15-preview";
                    var response = await httpClient.PostAsJsonAsync(
                        requestUri,
                        new { input = change.Payload }
                    );

                    if (response.StatusCode == HttpStatusCode.TooManyRequests)
                    {
                        var waitFor = response.Headers.RetryAfter.Delta.Value.TotalSeconds;
                        logger.LogInformation($"[{referenceTable}:{change.Id}] OpenAI had too many requests. Waiting {waitFor} seconds.");
                        await Task.Delay(TimeSpan.FromSeconds(waitFor));
                        continue;
                    }

                    response.EnsureSuccessStatusCode();

                    var jd = await response.Content.ReadAsAsync<JObject>();
                    var e = jd.SelectToken("data[0].embedding");
                    if (e != null)
                    {
                        using var conn = new SqlConnection(Environment.GetEnvironmentVariable("AZURE_SQL_CONNECTION_STRING"));
                        await conn.ExecuteAsync(
                            upsertStoredProcedure,
                            commandType: CommandType.StoredProcedure,
                            param: new
                            {
                                @id = change.Id,
                                @embeddings = e.ToString()
                            });
                        embeddingsReceived = true;
                        logger.LogInformation($"[{referenceTable}:{change.Id}] Done.");
                    }
                    else
                    {
                        logger.LogInformation($"[{referenceTable}:{change.Id}] No embeddings received.");
                    }

                    break;
                }
                if (!embeddingsReceived)
                {
                    logger.LogInformation($"[{referenceTable}:{change.Id}] Failed to get embeddings.");
                }
            }
        }

        [FunctionName("KeepAlive")]
        public static void RunOnTimerTrigger(
        [TimerTrigger("0 */1 * * * *")] TimerInfo myTimer,
        ILogger logger)
        {
            // Needed until SQL Trigger is GA.
            logger.LogInformation("Keep Alive Signal");
        }
    }
}
