using Microsoft.AspNetCore.SignalR;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text.Json;
using FirebaseAdmin.Messaging;

namespace SecureChatServer.Hubs;

public class SignalingHub : Hub
{
    // --- القواميس لتخزين بيانات المستخدمين المتصلين ---
    private static readonly ConcurrentDictionary<string, string> ConnectedUsers = new();    // ConnectionId -> PublicKey
    private static readonly ConcurrentDictionary<string, string> UserConnections = new();     // PublicKey -> ConnectionId
    private static readonly ConcurrentDictionary<string, string> UserDeviceTokens = new();    // PublicKey -> DeviceToken

    private static readonly ConcurrentDictionary<string, string> UserNames = new();           // PublicKey -> UserName

    // --- التعامل مع الاتصال والانقطاع ---
    public override Task OnConnectedAsync()
    {
        Debug.WriteLine($"--> [SERVER] Client connected: {Context.ConnectionId}");
        return base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        if (ConnectedUsers.TryRemove(Context.ConnectionId, out var publicKey))
        {
            UserConnections.TryRemove(publicKey, out _);
            Debug.WriteLine($"--> [SERVER] Client disconnected: {Context.ConnectionId}. User: {publicKey.Substring(0, 10)}...");
        }
        return base.OnDisconnectedAsync(exception);
    }

    // --- تسجيل المستخدمين وبياناتهم ---
    public void Identify(string publicKeyBase64, string userName) // تم إضافة اسم المستخدم
    {
        ConnectedUsers[Context.ConnectionId] = publicKeyBase64;
        UserConnections[publicKeyBase64] = Context.ConnectionId;
        UserNames[publicKeyBase64] = userName; // تخزين اسم المستخدم
        Debug.WriteLine($"--> [SERVER] User '{userName}' identified with key: {publicKeyBase64.Substring(0, 10)}...");
    }

    public void RegisterDeviceToken(string deviceToken)
    {
        if (ConnectedUsers.TryGetValue(Context.ConnectionId, out var publicKey))
        {
            UserDeviceTokens[publicKey] = deviceToken;
            Debug.WriteLine($"--> [SERVER] Device token registered for user {publicKey.Substring(0, 7)}...");
        }
    }

    // --- منطق إرسال الرسائل النصية ---
    public async Task SendMessage(string targetPublicKey, string type, object payload)
    {
        if (!ConnectedUsers.TryGetValue(Context.ConnectionId, out var callerPublicKey)) return;

        // البحث عن اسم المرسل
        UserNames.TryGetValue(callerPublicKey, out var callerName);
        callerName ??= "A Friend"; // اسم افتراضي إذا لم يتم العثور عليه

        if (UserConnections.TryGetValue(targetPublicKey, out var targetConnectionId))
        {
            await Clients.Client(targetConnectionId).SendAsync("ReceiveMessage", type, payload, callerPublicKey);
        }
        else if (UserDeviceTokens.TryGetValue(targetPublicKey, out var deviceToken))
        {
            var message = new Message()
            {
                Token = deviceToken,
                Notification = new Notification { Title = callerName, Body = "You have a new message." },
                Data = new Dictionary<string, string>() { { "notification_type", "text_message" } }
            };
            await SendFcmMessage(message, "TEXT");
        }
    }

    // --- منطق إرسال رسائل WebRTC (المكالمات) ---
    public async Task SendWebRtcMessage(string targetPublicKey, string type, object payload)
    {
        if (!ConnectedUsers.TryGetValue(Context.ConnectionId, out var callerPublicKey)) return;

        var finalPayload = payload is string ? payload : JsonSerializer.Serialize(payload);

        // إذا كان المستخدم متصلاً، أرسل الرسالة مباشرة
        if (UserConnections.TryGetValue(targetPublicKey, out var targetConnectionId))
        {
            await Clients.Client(targetConnectionId).SendAsync("WebRtcMessageReceived", type, finalPayload, callerPublicKey);
            return; // انتهت المهمة
        }

        // إذا كان المستخدم غير متصل، تعامل مع الإشعارات
        if (!UserDeviceTokens.TryGetValue(targetPublicKey, out var deviceToken)) return;

        // البحث عن اسم المرسل
        UserNames.TryGetValue(callerPublicKey, out var callerName);
        callerName ??= "A Friend"; 

        switch (type)
        {
            case "offer":
                var callMessage = new Message()
                {
                    Token = deviceToken,
                    Data = new Dictionary<string, string>()
        {
            { "notification_type", "incoming_call" },
            { "id", Guid.NewGuid().ToString() },
            { "nameCaller", callerName },
            { "handle", finalPayload.ToString() }, 
            { "callerPublicKey", callerPublicKey },
        },
                    Android = new AndroidConfig { Priority = Priority.High }
                };
                await SendFcmMessage(callMessage, "CALL");
                break;


            case "hangup_unanswered":
                var missedCallMessage = new Message()
                {
                    Token = deviceToken,
                    Notification = new Notification { Title = "Missed Call", Body = $"You missed a call from {callerName}." },
                    Data = new Dictionary<string, string>() { { "notification_type", "missed_call" } }
                };
                await SendFcmMessage(missedCallMessage, "MISSED CALL");
                break;
        }
    }

    // دالة مساعدة لإرسال إشعارات FCM مع معالجة الأخطاء
    private async Task SendFcmMessage(Message message, string type)
    {
        try
        {
            await FirebaseMessaging.DefaultInstance.SendAsync(message);
            Debug.WriteLine($"--> [SERVER] Successfully sent {type} notification.");
        }
        catch (Exception e)
        {
            Debug.WriteLine($"--> [SERVER] ERROR sending {type} notification: {e.Message}");
        }
    }
}
