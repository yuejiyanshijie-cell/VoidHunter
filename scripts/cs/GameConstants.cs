namespace VoidHunter;

/// <summary>Global game constants shared across all modules.</summary>
public static partial class GameConstants
{
    // Display
    public const int GameWidth = 960;
    public const int GameHeight = 540;
    public const float PixelScale = 2f;

    // Physics
    public const float Gravity = 1200f;
    public const float TerminalVelocity = 600f;

    // Player
    public const float PlayerSpeed = 220f;
    public const float JumpVelocity = -440f;
    public const float DoubleJumpVelocity = -360f;
    public const float DashSpeed = 600f;
    public const float DashDuration = 0.18f;
    public const float DashCooldown = 0.6f;
    public const float WallSlideSpeed = 80f;
    public const float WallJumpH = 300f;
    public const float WallJumpV = -400f;
    public const float PlayerMaxHealth = 100f;

    // Combat
    public const float AtkLight = 10f;
    public const float AtkHeavy = 25f;
    public const float AtkDownstrike = 18f;
    public const float DodgeDuration = 0.3f;
    public const float DodgeCooldown = 0.5f;

    // Skills
    public const float Skill1Damage = 20f;
    public const float Skill1Knockback = 400f;
    public const float Skill1Cooldown = 3f;
    public const float Skill1Range = 150f;
    public const float Skill2Damage = 35f;
    public const float Skill2Range = 120f;
    public const float Skill2Cooldown = 8f;

    // Input buffer
    public const float JumpBuffer = 0.1f;
    public const float CoyoteTime = 0.08f;
}
