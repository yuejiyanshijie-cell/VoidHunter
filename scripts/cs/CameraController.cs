using Godot;

namespace VoidHunter;

/// <summary>
/// Camera2D extension — smooth follow player + screen shake via offset.
/// Uses direct property access to Player (no reflection).
/// </summary>
public partial class CameraController : Camera2D
{
    [Export] public Node2D FollowTarget { get; set; }
    [Export] public float FollowSpeed { get; set; } = 8f;
    [Export] public float LookAhead { get; set; } = 80f;
    [Export] public float LookAheadVertical { get; set; } = 20f;

    private float _shakeAmplitude;
    private float _shakeDuration;
    private float _shakeTimer;
    private Vector2 _originalOffset;

    public override void _Ready()
    {
        _originalOffset = Offset;
        EventBus.Instance.ScreenShakeRequest += OnScreenShake;
    }

    public override void _Process(double delta)
    {
        var d = (float)delta;
        if (FollowTarget != null)
            SmoothFollow(d);
        UpdateShake(d);
    }

    // =========================================================================
    // Smooth Follow — lerp toward target with look-ahead
    // =========================================================================
    private void SmoothFollow(float delta)
    {
        var targetPos = FollowTarget.GlobalPosition;

        // Look-ahead based on player facing and velocity
        var lookOffset = Vector2.Zero;
        float facing = 1f;
        float velY = 0f;

        // Direct property access to Player type — no reflection
        if (FollowTarget is Player pl)
        {
            facing = pl.FacingDirection;
            velY = pl.Velocity.Y;
        }
        else
        {
            // Fallback for non-Player targets: try reflection via object properties
            var fd = FollowTarget.Get("facing_direction");
            if (fd.VariantType != Variant.Type.Nil)
                facing = fd.AsSingle();
            var v = FollowTarget.Get("velocity");
            if (v.VariantType != Variant.Type.Nil)
                velY = v.AsVector2().Y;
        }

        lookOffset.X = facing * LookAhead;
        if (velY < 0)
            lookOffset.Y = -LookAheadVertical;
        else if (velY > 100)
            lookOffset.Y = LookAheadVertical;

        targetPos += lookOffset;

        float weight = Mathf.Min(FollowSpeed * delta, 1f);
        GlobalPosition = GlobalPosition.Lerp(targetPos, weight);
    }

    // =========================================================================
    // Screen Shake — accumulates amplitude/duration requests
    // =========================================================================
    private void OnScreenShake(float amplitude, float duration)
    {
        _shakeAmplitude = Mathf.Max(_shakeAmplitude, amplitude);
        _shakeDuration = Mathf.Max(_shakeDuration, duration);
        _shakeTimer = _shakeDuration;
    }

    private void UpdateShake(float delta)
    {
        if (_shakeTimer <= 0)
        {
            Offset = _originalOffset;
            return;
        }
        _shakeTimer -= delta;
        float t = _shakeTimer / Mathf.Max(_shakeDuration, 0.001f);
        Offset = _originalOffset + new Vector2(
            (GD.Randf() * _shakeAmplitude * 2f - _shakeAmplitude) * t,
            (GD.Randf() * _shakeAmplitude * 2f - _shakeAmplitude) * t);
    }
}
