public class UserInfo
{
    public string ConnectionId { get; set; }
    public byte[]? PublicKey { get; set; } 

    public UserInfo(string connectionId)
    {
        ConnectionId = connectionId;
    }
}
