using System.ComponentModel.DataAnnotations;

namespace SecureChatServer.DTOs
{
    public class AuthDtos
    {
        public class RegisterDto
        {
            [Required]
            public string? Username { get; set; }

            [Required]
            [EmailAddress]
            public string? Email { get; set; }

            [Required]
            public string? Password { get; set; }
        }

        public class LoginDto
        {
            [Required]
            public string? Username { get; set; }

            [Required]
            public string? Password { get; set; }
        }

        public class AuthResponseDto
        {
            public bool IsSuccess { get; set; }
            public string? Message { get; set; }
        }
    }
}
