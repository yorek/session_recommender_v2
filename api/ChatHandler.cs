using System;
using System.IO;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Data.SqlClient;
using Newtonsoft.Json;
using Dapper;
using Azure.AI.OpenAI;
using System.ComponentModel.DataAnnotations;
using Azure;
using Azure.Identity;

namespace SessionRecommender
{

    public class ChatHandler
    {
        public record ChatTurn(string userPrompt, string? responseMessage);

        public record FoundSession(
            int Id,
            string Title,
            string Abstract,
            double Similarity,
            //string RecordingUrl, 
            string Speakers,
            string ExternalId
        //DateTimeOffset Start, 
        //DateTimeOffset End
        );

        private readonly string _openAIDeploymentName = Environment.GetEnvironmentVariable("AZURE_OPENAI_GPT_DEPLOYMENT_NAME") ?? "gpt-4";

        private const string SystemMessage = """
You are a system assistant who helps users find the right session to watch from the conference, based off the sessions that are provided to you.

Sessions will be provided in an assistant message in the format of `title|abstract|speakers`. You can use this information to help you answer the user's question.
""";

        private readonly OpenAIClient openAIClient;

        public ChatHandler()
        {
            Uri openaiEndPoint = Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT") is string value &&
                Uri.TryCreate(value, UriKind.Absolute, out Uri? uri) &&
                uri is not null
                ? uri
                : throw new ArgumentException(
                $"Unable to parse endpoint URI");

            OpenAIClient openAIClient = Environment.GetEnvironmentVariable("AZURE_OPENAI_KEY") is string key ?
                new(openaiEndPoint, new AzureKeyCredential(key)) :
                new(openaiEndPoint, new DefaultAzureCredential());

            this.openAIClient = openAIClient;
        }

        [FunctionName("ChatHandler")]
        public async IAsyncEnumerable<string> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = "ask")] HttpRequest req,
            ILogger logger)
        {
            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            ChatTurn[] history = JsonConvert.DeserializeObject<ChatTurn[]>(requestBody ?? "[]");

            logger.LogInformation("Retrieving similar sessions...");

            DynamicParameters p = new();
            p.Add("@text", history.Last().userPrompt);
            p.Add("@top", 25);
            p.Add("@min_similarity", 0.70);

            Console.WriteLine("Executing query...");

            using SqlConnection conn = new SqlConnection(Environment.GetEnvironmentVariable("AZURE_SQL_CONNECTION_STRING"));
            using IDataReader foundSessions = await conn.ExecuteReaderAsync("[web].[find_sessions]", commandType: CommandType.StoredProcedure, param: p);
            List<FoundSession> sessions = [];
            while (foundSessions.Read())
            {
                sessions.Add(new(
                    Id: foundSessions.GetInt32(0),
                    Title: foundSessions.GetString(1),
                    Abstract: foundSessions.GetString(2),
                    ExternalId: foundSessions.GetString(3),
                    //Start: foundSessions.GetDateTime(4),
                    //End: foundSessions.GetDateTime(5),
                    //RecordingUrl: foundSessions.GetString(6),
                    Speakers: foundSessions.GetString(7),
                    Similarity: foundSessions.GetDouble(8)
                ));
            }

            logger.LogInformation("Calling GPT...");

            string sessionDescriptions = string.Join("\r", sessions.Select(s => $"{s.Title}|{s.Abstract}|{s.Speakers}"));

            List<ChatRequestMessage> messages = [new ChatRequestSystemMessage(SystemMessage)];

            foreach (ChatTurn turn in history)
            {
                messages.Add(new ChatRequestUserMessage(turn.userPrompt));
                if (turn.responseMessage is not null)
                {
                    messages.Add(new ChatRequestAssistantMessage(turn.responseMessage));
                }
            }

            messages.Add(new ChatRequestUserMessage($@"## Source ##
{sessionDescriptions}
## End ##

You answer needs to divided in two sections: in the first section you'll add the answer to the question.
In the second section, that must be named exactly '###thoughts###' (and make sure to use the section name as typed, without any changes) you'll write brief thoughts on how you came up with the answer, e.g. what sources you used, what you thought about, etc.
}}"));

            ChatCompletionsOptions options = new(_openAIDeploymentName, messages);

            var answerContent = "";
            await foreach (StreamingChatCompletionsUpdate chatUpdate in openAIClient.GetChatCompletionsStreaming(options))
            {
                if (chatUpdate.Role.HasValue)
                {
                    Console.Write($"{chatUpdate.Role.Value.ToString().ToUpperInvariant()}: ");
                    answerContent += chatUpdate.ContentUpdate;
                }
                if (!string.IsNullOrEmpty(chatUpdate.ContentUpdate))
                {
                    Console.Write(chatUpdate.ContentUpdate);
                    answerContent += chatUpdate.ContentUpdate;
                }

                //var answerPayload = await openAIClient.GetChatCompletionsAsync(options);
                //var answerContent = answerPayload.Value.Choices[0].Message.Content;

                //logger.LogInformation(answerContent);            

                var answerPieces = answerContent
                    .Replace("###Thoughts###", "###thoughts###", StringComparison.InvariantCultureIgnoreCase)
                    .Replace("### Thoughts ###", "###thoughts###", StringComparison.InvariantCultureIgnoreCase)
                    .Split("###thoughts###", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                if (answerPieces.Length > 0)
                {
                    var answer = answerPieces[0];
                    var thoughts = answerPieces.Length == 2 ? answerPieces[1] : "No thoughts provided.";

                    Console.WriteLine("Answer: " + answer);
                    yield return answer;
                } else {
                    yield return answerContent;
                }
            }

            logger.LogInformation("Done.");

            // return new OkObjectResult(new
            // {
            //     answer,
            //     thoughts,
            //     dataPoints = sessions.Select(s => new { title = s.Title, content = s.Abstract, url = "", similarity = s.Similarity }),
            // });                    
        }
    }
}