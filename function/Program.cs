using Azure;
using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()

.ConfigureServices(services =>
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

    services.AddSingleton(openAIClient);

    services.AddTransient((_) => new SqlConnection(Environment.GetEnvironmentVariable("AZURE_SQL_CONNECTION_STRING")));

})
.ConfigureFunctionsWebApplication()
.Build();

host.Run();