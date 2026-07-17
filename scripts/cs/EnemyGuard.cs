using Godot;

namespace VoidHunter;

/// <summary>Energy guard — patrol, keep distance, shoot projectiles.</summary>
public partial class EnemyGuard : CharacterBody2D
{
    private enum State { Idle, Patrol, Chase, Stunned, Dead }
    private State _state = State.Idle;
    private float _health = 80;
    private const float MaxHp = 80;
    private const float Speed = 60;
    private const float Damage = 15;
    private const float DetectRange = 350;
    private const float IdealDist = 150;
    private const float KbResist = 2f;

    private CharacterBody2D _player;
    private float _stunTimer;
    private float _patrolDir = -1;
    private float _patrolTimer;
    private float _shootCd;
    private ColorRect _body;

    public override void _Ready()
    {
        _health = MaxHp;
        _body = new ColorRect { Size = new Vector2(22, 22), Position = new Vector2(-11, -11), Color = new Color(0.3f, 0.3f, 0.6f) };
        AddChild(_body);
        var core = new ColorRect { Size = new Vector2(8, 8), Position = new Vector2(-4, -4), Color = new Color(0.5f, 0.4f, 1f) };
        _body.AddChild(core);
    }

    public override void _Process(double delta)
    {
        if (_state == State.Dead) return;
        var d = (float)delta;
        _stunTimer = Mathf.Max(0, _stunTimer - d);
        _shootCd = Mathf.Max(0, _shootCd - d);
        if (_stunTimer <= 0 && _state == State.Stunned) _state = State.Idle;
        switch (_state) { case State.Idle: case State.Patrol: SearchPlayer(); PatrolMove(d); break; case State.Chase: if (_player != null) ChasePlayer(); else _state = State.Patrol; break; }
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_state == State.Dead) { Velocity = Vector2.Zero; MoveAndSlide(); return; }
        Velocity = new Vector2(Velocity.X, Mathf.Min(Velocity.Y + GameConstants.Gravity * (float)delta, GameConstants.TerminalVelocity));
        MoveAndSlide();
        if (Mathf.Abs(Velocity.X) > 5) _body.Scale = new Vector2(Mathf.Sign(Velocity.X), 1);
    }

    private void SearchPlayer()
    {
        if (_player != null && GlobalPosition.DistanceTo(_player.GlobalPosition) > DetectRange * 1.5f) _player = null;
        if (_player == null)
        {
            var players = GetTree().GetNodesInGroup("player");
            if (players.Count > 0) { var p = players[0] as CharacterBody2D; if (p != null && GlobalPosition.DistanceTo(p.GlobalPosition) < DetectRange) { _player = p; _state = State.Chase; } }
        }
    }
    private void PatrolMove(float d) { _patrolTimer += d; if (_patrolTimer > 2.5f) { _patrolTimer = 0; _patrolDir *= -1; } Velocity = new Vector2(_patrolDir * Speed * 0.3f, Velocity.Y); }
    private void ChasePlayer()
    {
        var dist = GlobalPosition.DistanceTo(_player.GlobalPosition);
        var dir = Mathf.Sign(_player.GlobalPosition.X - GlobalPosition.X);
        if (dist > IdealDist + 50) Velocity = new Vector2(dir * Speed, Velocity.Y);
        else if (dist < IdealDist - 50) Velocity = new Vector2(-dir * Speed, Velocity.Y);
        else { Velocity = new Vector2(0, Velocity.Y); if (_shootCd <= 0) Shoot(dir); }
    }
    private void Shoot(float dir)
    {
        _shootCd = 1.8f;
        var bullet = new EnemyBullet
        {
            Position = GlobalPosition + new Vector2(dir * 16, -6),
            BulletVelocity = new Vector2(dir * 200, 0),
            Damage = Damage,
            Source = this,
            Lifetime = 2f
        };
        GetParent().AddChild(bullet);
    }

    public void TakeDamage(float amount, Node2D source)
    {
        if (_state == State.Dead) return;
        _health = Mathf.Max(0, _health - amount);
        if (source is CharacterBody2D) Velocity = new Vector2(Mathf.Sign(GlobalPosition.X - source.GlobalPosition.X) * 150 / KbResist, Velocity.Y);
        _state = State.Stunned; _stunTimer = 0.25f;
        var t = CreateTween(); t.TweenProperty(_body, "modulate", Colors.White, 0.06f); t.TweenProperty(_body, "modulate", Colors.White, 0.1f);
        EventBus.Instance.EmitSignal(EventBus.SignalName.DamageNumberRequest, amount, GlobalPosition, false);
        if (_health <= 0) Die();
    }
    private void Die() { _state = State.Dead; EventBus.Instance.EmitSignal(EventBus.SignalName.EnemyKilled, this, GlobalPosition); var t = CreateTween(); t.TweenProperty(_body, "modulate:a", 0f, 0.5f); t.TweenCallback(Callable.From(QueueFree)); }
}
