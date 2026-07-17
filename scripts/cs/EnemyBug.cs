using Godot;

namespace VoidHunter;

/// <summary>Alien mech bug — patrol, chase, melee contact damage.</summary>
public partial class EnemyBug : CharacterBody2D
{
    private enum State { Idle, Patrol, Chase, Attack, Stunned, Dead }
    private State _state = State.Idle;
    private float _health = 30;
    private const float MaxHp = 30;
    private const float Speed = 120;
    private const float Damage = 10;
    private const float DetectRange = 250;
    private const float KbResist = 0.5f;

    private CharacterBody2D _player;
    private float _stunTimer;
    private Vector2 _spawn;
    private float _patrolDir = -1;
    private float _patrolTimer;
    private float _atkCd;
    private bool _canAttack = true;
    private ColorRect _body;

    public override void _Ready()
    {
        _health = MaxHp; _spawn = GlobalPosition;
        _body = new ColorRect { Size = new Vector2(20, 10), Position = new Vector2(-10, -5), Color = new Color(0.4f, 0.3f, 0.2f) };
        AddChild(_body);
        var eye = new ColorRect { Size = new Vector2(3, 3), Position = new Vector2(6, -3), Color = new Color(1, 0.2f, 0.1f) };
        _body.AddChild(eye);
    }

    public override void _Process(double delta)
    {
        if (_state == State.Dead) return;
        var d = (float)delta;
        UpdateTimers(d);

        switch (_state)
        {
            case State.Idle:
            case State.Patrol:
                SearchPlayer();
                if (_state == State.Patrol) PatrolMove(d);
                break;
            case State.Chase:
                if (_player != null) ChasePlayer();
                else SetState(State.Patrol);
                break;
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_state == State.Dead) { Velocity = Vector2.Zero; MoveAndSlide(); return; }
        Velocity = new Vector2(Velocity.X, Mathf.Min(Velocity.Y + GameConstants.Gravity * (float)delta, GameConstants.TerminalVelocity));
        if (_state != State.Stunned) MoveAndSlide();
        if (Velocity.X != 0) _body.Scale = new Vector2(Mathf.Sign(Velocity.X), 1);
    }

    // =========================================================================
    // Timers & State Machine
    // =========================================================================
    private void UpdateTimers(float delta)
    {
        if (_stunTimer > 0)
        {
            _stunTimer = Mathf.Max(0, _stunTimer - delta);
            if (_stunTimer <= 0 && _state == State.Stunned)
                SetState(State.Idle);
        }
        if (_atkCd > 0)
        {
            _atkCd = Mathf.Max(0, _atkCd - delta);
            if (_atkCd <= 0) _canAttack = true;
        }
        if (_state == State.Patrol)
        {
            _patrolTimer += delta;
            if (_patrolTimer > 2f) { _patrolTimer = 0; _patrolDir *= -1; }
        }
    }

    private void SetState(State s)
    {
        if (_state == s) return;
        _state = s;
        switch (s)
        {
            case State.Idle:
                // Auto-transition to patrol after brief idle
                GetTree().CreateTimer(0.5f).Timeout += () =>
                {
                    if (_state == State.Idle) SetState(State.Patrol);
                };
                break;
            case State.Patrol:
                Velocity = new Vector2(_patrolDir * Speed * 0.4f, Velocity.Y);
                break;
        }
    }

    // =========================================================================
    // AI Behaviors
    // =========================================================================
    private void SearchPlayer()
    {
        if (_player != null && GlobalPosition.DistanceTo(_player.GlobalPosition) > DetectRange * 1.5f)
        {
            _player = null;
            SetState(State.Patrol);
        }
        if (_player == null)
        {
            var players = GetTree().GetNodesInGroup("player");
            if (players.Count > 0)
            {
                var p = players[0] as CharacterBody2D;
                if (p != null && GlobalPosition.DistanceTo(p.GlobalPosition) < DetectRange)
                {
                    _player = p;
                    SetState(State.Chase);
                }
            }
        }
    }

    private void PatrolMove(float d)
    {
        Velocity = new Vector2(_patrolDir * Speed * 0.4f, Velocity.Y);
    }

    private void ChasePlayer()
    {
        if (_player == null) return;
        var dir = Mathf.Sign(_player.GlobalPosition.X - GlobalPosition.X);
        Velocity = new Vector2(dir * Speed, Velocity.Y);

        // Contact damage — melee attack
        if (GlobalPosition.DistanceTo(_player.GlobalPosition) < 24 && _canAttack)
            MeleeAttack();
    }

    private void MeleeAttack()
    {
        if (_player == null) return;
        _canAttack = false;
        _atkCd = 0.8f;
        _player.Call("take_damage", Damage, this);
        EventBus.Instance.EmitSignal(EventBus.SignalName.HitEffectRequest, _player.GlobalPosition, "hit");
        // Knockback recoil
        Velocity = new Vector2(-Mathf.Sign(_player.GlobalPosition.X - GlobalPosition.X) * 100, Velocity.Y);
    }

    // =========================================================================
    // Damage / Death
    // =========================================================================
    public void TakeDamage(float amount, Node2D source)
    {
        if (_state == State.Dead) return;
        _health = Mathf.Max(0, _health - amount);
        if (source is CharacterBody2D)
            Velocity = new Vector2(Mathf.Sign(GlobalPosition.X - source.GlobalPosition.X) * (200f / KbResist), Velocity.Y);

        _state = State.Stunned;
        _stunTimer = 0.2f;

        // Flash white
        var t = CreateTween();
        t.TweenProperty(_body, "modulate", Colors.White, 0.06f);
        t.TweenProperty(_body, "modulate", Colors.White, 0.1f);

        EventBus.Instance.EmitSignal(EventBus.SignalName.DamageNumberRequest, amount, GlobalPosition, false);

        if (_health <= 0) Die();
    }

    private void Die()
    {
        _state = State.Dead;
        EventBus.Instance.EmitSignal(EventBus.SignalName.EnemyKilled, this, GlobalPosition);
        var t = CreateTween();
        t.TweenProperty(_body, "modulate:a", 0f, 0.4f);
        t.TweenCallback(Callable.From(QueueFree));
    }
}
