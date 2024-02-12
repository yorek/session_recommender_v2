using Microsoft.Extensions.Logging;
using Microsoft.Data.SqlClient;
using System.Data;
using Dapper;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Sql;
using Azure.AI.OpenAI;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace SessionRecommender.RequestHandler;

public class KeepAlive(ILogger<KeepAlive> logger)
{

    [Function("KeepAlive")]
    public void RunOnTimerTrigger([TimerTrigger("0 */1 * * * *")] TimerInfo myTimer)
    {
        // Needed until SQL Trigger is GA.
        logger.LogInformation("Keep-Alive Signal");
    }
}

