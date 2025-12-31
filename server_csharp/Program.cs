using SecureChatServer.Hubs;
using FirebaseAdmin; 
using Google.Apis.Auth.OAuth2; 

var builder = WebApplication.CreateBuilder(args);

try
{
    FirebaseApp.Create(new AppOptions()
    {
        Credential = GoogleCredential.FromFile("firebase-adminsdk.json"),
    });
    Console.WriteLine("✅ Firebase Admin SDK initialized successfully.");
}
catch (Exception ex)
{
    Console.WriteLine($"❌ Error initializing Firebase Admin SDK: {ex.Message}");
}

builder.Services.AddSignalR();
builder.Services.AddCors(options => {
    options.AddPolicy("AllowAll", policy => {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseRouting();
app.UseCors("AllowAll");

app.MapHub<SignalingHub>("/signalinghub");

app.Run();
