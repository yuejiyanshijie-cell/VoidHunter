using Godot;

namespace VoidHunter;

/// <summary>
/// Energy bullet fired by EnemyGuard. Drives itself via _Process.
/// Hits player or world geometry, self-destructs with FX.
/// </summary>
public partial class EnemyBullet : Area2D
{
    public Vector2 BulletVelocity { get; set; } = Vector2.Zero;
    public float Damage { get; set; } = 15f;
    public Node2D Source { get; set; }
    public float Lifetime { get; set; } = 3f;

    private ColorRect _visual;

    public override void _Ready()
    {
        // Collision setup
        CollisionLayer = 0;
        CollisionMask = 1; // hit layer 1 (player / world)

        var collShape = new CollisionShape2D();
        collShape.Shape = new RectangleShape2D { Size = new Vector2(10, 6) };
        AddChild(collShape);

        _visual = new ColorRect
        {
            Size = new Vector2(8, 6),
            Position = new Vector2(-4, -3),
            Color = new Color(0.3f, 0.2f, 1f)
        };
        AddChild(_visual);

        BodyEntered += OnHit;
        AreaEntered += OnHitArea;
    }

    public override void _Process(double delta)
    {
        Position += BulletVelocity * (float)delta;
        Lifetime -= (float)delta;
        if (Lifetime <= 0)
            QueueFree();
    }

    private void OnHit(Node2D body)
    {
        if (body == Source) return;
        if (body.HasMethod("take_damage"))
        {
            body.Call("take_damage", Damage, Source);
            EventBus.Instance.EmitSignal(EventBus.SignalName.HitEffectRequest, GlobalPosition, "hit");
            ExplodeAndFree();
        }
    }

    private void OnHitArea(Area2D area)
    {
        var body = area.GetParent() as Node2D;
        if (body == null || body == Source) return;
        if (body.HasMethod("take_damage"))
        {
            body.Call("take_damage", Damage, Source);
            EventBus.Instance.EmitSignal(EventBus.SignalName.HitEffectRequest, GlobalPosition, "hit");
            ExplodeAndFree();
        }
    }

    private void ExplodeAndFree()
    {
        SetProcess(false);
        var t = CreateTween();
        t.TweenProperty(_visual, "modulate:a", 0.0, 0.15);
        t.TweenCallback(Callable.From(QueueFree));
    }
}
