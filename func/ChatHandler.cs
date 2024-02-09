using System;
using System.Data;
using System.Text.Json;
using Azure;
using Azure.AI.OpenAI;
using Dapper;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using FromBodyAttribute = Microsoft.Azure.Functions.Worker.Http.FromBodyAttribute;

namespace SessionRecommender.SessionProcessor;

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

public class Asker(OpenAIClient openAIClient, SqlConnection conn, ILogger<Asker> logger)
{
    private const string SystemMessage = """
You as a system assistant who helps users find the right session to watch from the conference, based off the sessions that are provided to you.

Sessions will be provided in an assistant message in the format of `title|abstract|speakers`. You can use this information to help you answer the user's question.
""";

    [Function("ask")]
    public async Task<IActionResult> AskAsync(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequest req,
        [FromBody] ChatTurn[] history)
    {
        logger.LogInformation("Retrieving similar sessions...");

        DynamicParameters p = new();
        p.Add("@text", history.Last().userPrompt);
        p.Add("@top", 10);
        p.Add("@min_similarity", 0.70);

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

        messages.Add(new ChatRequestUserMessage($@" ## Source ##
{sessionDescriptions}
## End ##

You answer needs to divided in two section: in the first you'll add the answer to the question, also add a source reference to the end of each sentence. e.g. Apple is a fruit [reference1.pdf][reference2.pdf]. If no source available, put the answer as I don't know.
then you'll add a second section the must be named exactly '###thoughts###' where you'll write brief thoughts on how you came up with the answer, e.g. what sources you used, what you thought about, etc.
}}"));

        ChatCompletionsOptions options = new("gpt-4-32k", messages);

        try
        {
            var answerPayload = await openAIClient.GetChatCompletionsAsync(options);
            var answerContent = answerPayload.Value.Choices[0].Message.Content;
            logger.LogInformation(answerContent);            
            var answerPieces = answerContent.Split("###thoughts###");
            var answer = answerPieces[0];
            var thoughts = answerPieces.Length == 2 ? answerPieces[1] : "No thoughts provided.";
            
            logger.LogInformation("Done.");

            return new OkObjectResult(new
            {
                answer,
                thoughts,
                dataPoints = sessions.Select(s => new { title = s.Title, content = s.Abstract, url = "", similarity = s.Similarity }),
            });
        }
        catch (Exception e)
        {
            logger.LogError(e, "Failed to get answer from OpenAI.");
            return new BadRequestObjectResult(e.Message);
        }
    }
}