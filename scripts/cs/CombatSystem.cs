using Godot;

namespace VoidHunter;

/// <summary>
/// Combat visual effects system — damage numbers, hit effects, screen shake, hit-stop.
/// Created by code (no .tscn), initialized by SceneManager with world + camera references.
/// </summary>
public partial class CombatSystem : Node
{
    private Node2D _worldNode;
    private Camera2D _camera;

    public void Initialize(Node2D world, Camera2D cam)
    {
        _worldNode = world;
        _camera = cam;
        EventBus.Instance.DamageNumberRequest += OnDamageNumber;
        EventBus.Instance.HitEffectRequest += OnHitEffect;
        EventBus.Instance.ScreenShakeRequest += OnShake;
        EventBus.Instance.TimeScaleRequest += OnTimeScale;
    }

    // =========================================================================
    // Damage Numbers — float upward and fade out
    // =========================================================================
    private void OnDamageNumber(float amount, Vector2 pos, bool isCrit)
    {
        var label = new Label
        {
            Text = Mathf.CeilToInt(amount).ToString(),
            Position = pos + new Vector2(GD.Randf() * 30f - 15f, -20f),
            ZIndex = 100
        };
        label.AddThemeFontSizeOverride("font_size", isCrit ? 18 : 14);
        label.AddThemeColorOverride("font_color", isCrit ? Colors.Yellow : Colors.White);
        label.AddThemeColorOverride("font_outline_color", Colors.Black);
        label.AddThemeConstantOverride("outline_size", 2);
        _worldNode.AddChild(label);

        var t = CreateTween().SetParallel();
        t.TweenProperty(label, "position:y", pos.Y - 50f, 0.6).SetEase(Tween.EaseType.Out);
        t.TweenProperty(label, "position:x", pos.X + GD.Randf() * 30f - 15f, 0.6);
        t.TweenProperty(label, "modulate:a", 0.0, 0.35).SetDelay(0.25);
        t.Chain().TweenCallback(Callable.From(label.QueueFree));

        // Crit bonus ring
        if (isCrit)
        {
            var ring = new ColorRect
            {
                Size = new Vector2(30, 30),
                Position = pos + new Vector2(-15, -15),
                Color = new Color(1f, 0.85f, 0.2f, 0.5f),
                ZIndex = 99
            };
            _worldNode.AddChild(ring);
            var rt = CreateTween();
            rt.TweenProperty(ring, "size", new Vector2(60, 60), 0.2f);
            rt.Parallel().TweenProperty(ring, "position", pos + new Vector2(-30, -30), 0.2f);
            rt.Parallel().TweenProperty(ring, "color:a", 0.0, 0.2f);
            rt.TweenCallback(Callable.From(ring.QueueFree));
        }
    }

    // =========================================================================
    // Hit Effects — dispatched by type string
    // =========================================================================
    private void OnHitEffect(Vector2 pos, string type)
    {
        switch (type)
        {
            case "hit":       HitSparks(pos);  break;
            case "slash":     SlashTrail(pos); break;
            case "blast":     BlastWave(pos);  break;
            case "void_slash": VoidRing(pos);  break;
            default:          HitSparks(pos);  break;
        }
    }

    private void HitSparks(Vector2 pos)
    {
        for (int i = 0; i < 4; i++)
        {
            var s = new ColorRect
            {
                Size = new Vector2(3, 3),
                Position = pos + new Vector2(GD.Randf() * 12f - 6f, GD.Randf() * 12f - 6f),
                Color = new Color(0.9f, 0.9f, 1f),
                ZIndex = 50
            };
            _worldNode.AddChild(s);
            var t = CreateTween();
            float dx = GD.Randf() * 100f - 50f;
            float dy = GD.Randf() * 60f - 40f;
            t.TweenProperty(s, "position", s.Position + new Vector2(dx, dy), 0.2f);
            t.Parallel().TweenProperty(s, "size", Vector2.Zero, 0.2f);
            t.Parallel().TweenProperty(s, "color:a", 0.0, 0.2f);
            t.TweenCallback(Callable.From(s.QueueFree));
        }
    }

    private void SlashTrail(Vector2 pos)
    {
        var arc = new ColorRect
        {
            Size = new Vector2(20, 4),
            Position = pos,
            Color = new Color(0.4f, 0.5f, 1f, 0.5f),
            ZIndex = 50
        };
        _worldNode.AddChild(arc);
        var t = CreateTween();
        t.TweenProperty(arc, "size:x", 40f, 0.12f);
        t.Parallel().TweenProperty(arc, "color:a", 0.0, 0.15f);
        t.TweenCallback(Callable.From(arc.QueueFree));
    }

    private void BlastWave(Vector2 pos)
    {
        var wave = new ColorRect
        {
            Size = new Vector2(10, 6),
            Position = pos + new Vector2(-5, -3),
            Color = new Color(0.3f, 0.6f, 1f, 0.5f),
            ZIndex = 50
        };
        _worldNode.AddChild(wave);
        var t = CreateTween();
        t.TweenProperty(wave, "size", new Vector2(60, 20), 0.2f);
        t.Parallel().TweenProperty(wave, "position", pos + new Vector2(-30, -10), 0.2f);
        t.Parallel().TweenProperty(wave, "color:a", 0.0, 0.2f);
        t.TweenCallback(Callable.From(wave.QueueFree));
    }

    private void VoidRing(Vector2 pos)
    {
        for (int i = 0; i < 3; i++)
        {
            var ring = new ColorRect
            {
                Size = new Vector2(20, 20),
                Position = pos + new Vector2(-10, -10),
                Color = new Color(0.5f, 0.25f, 1f, 0.4f),
                ZIndex = 50
            };
            _worldNode.AddChild(ring);
            var t = CreateTween();
            t.TweenProperty(ring, "size", new Vector2(60, 60), 0.3f);
            t.Parallel().TweenProperty(ring, "position", pos + new Vector2(-30, -30), 0.3f);
            t.Parallel().TweenProperty(ring, "color:a", 0.0, 0.3f);
            t.TweenCallback(Callable.From(ring.QueueFree));
        }
    }

    // =========================================================================
    // Screen Shake — uses TweenMethod with a Callable lambda
    // =========================================================================
    private void OnShake(float amplitude, float duration)
    {
        if (_camera == null) return;
        var start = _camera.GlobalPosition;
        int count = Mathf.Max(1, Mathf.CeilToInt(duration * 50f));
        var t = CreateTween().SetLoops(count);
        t.TweenMethod(
            Callable.From<double>(_ =>
            {
                _camera.GlobalPosition = start + new Vector2(
                    GD.Randf() * amplitude * 2f - amplitude,
                    GD.Randf() * amplitude * 2f - amplitude);
            }),
            0.0, 0.0, 0.02);
        t.Finished += () => _camera.GlobalPosition = start;
    }

    // =========================================================================
    // Hit Stop — temporarily slow Engine.TimeScale
    // =========================================================================
    private void OnTimeScale(float scale, float duration)
    {
        var orig = Engine.TimeScale;
        Engine.TimeScale = Mathf.Max(scale, 0.1f);
        GetTree().CreateTimer(duration * scale, true, false, true).Timeout +=
            () => Engine.TimeScale = orig;
    }
}
