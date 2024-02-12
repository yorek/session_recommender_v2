using System;
using System.IO;
using Azure;
using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

[assembly: FunctionsStartup(typeof(SessionRecommender.Startup))]

namespace SessionRecommender
{
    public class Startup : FunctionsStartup
    {
        public override void Configure(IFunctionsHostBuilder builder)
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

            builder.Services.AddSingleton(openAIClient);

            builder.Services.AddTransient((_) => new SqlConnection(Environment.GetEnvironmentVariable("AZURE_SQL_CONNECTION_STRING")));
        }
    }
}
