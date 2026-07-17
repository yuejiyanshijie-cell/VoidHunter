using Godot;
using System.Collections.Generic;

namespace VoidHunter;

/// <summary>Mutant mech boss — Phase1 melee charge/jump/slam, Phase2 adds area blast.</summary>
public partial class EnemyBoss : CharacterBody2D
{
    private enum BossPhase { Phase1, Phase2 }
    private BossPhase _phase = BossPhase.Phase1;

    private float _health = 500;
    private const float MaxHp = 500;
    private const float AttackDamage = 25;
    private float _moveSpeed = 150;
    private const float KbResist = 5f;
    private const float DetectRange = 500;

    private CharacterBody2D _player;
    private float _stunTimer;
    private bool _isStunned;

    // AI
    private float _actionTimer;
    private string _currentAction = "idle";
    private float _chargeSpeed = 400;
    private bool _isCharging;
    private float _jumpTimer;

    // Visuals
    private ColorRect _body;
    private ColorRect _armor;
    private readonly List<ColorRect> _eyes = new();
    private ColorRect _healthBar;
    private ColorRect _healthBg;

    public override void _Ready()
    {
        _health = MaxHp;
        CreateVisual();
    }

    private void CreateVisual()
    {
        // Body
        _body = new ColorRect { Size = new Vector2(40, 30), Position = new Vector2(-20, -15), Color = new Color(0.15f, 0.15f, 0.25f) };
        AddChild(_body);

        // Armor
        _armor = new ColorRect { Size = new Vector2(38, 8), Position = new Vector2(-19, -11), Color = new Color(0.55f, 0.15f, 0.15f) };
        _body.AddChild(_armor);

        // Eyes
        for (int i = 0; i < 3; i++)
        {
            var eye = new ColorRect { Size = new Vector2(4, 3), Position = new Vector2(-8 + i * 6, -7), Color = new Color(0.6f, 0.2f, 1f) };
            _body.AddChild(eye);
            _eyes.Add(eye);
        }

        // Claws
        foreach (int side in new[] { -1, 1 })
        {
            var claw = new ColorRect { Size = new Vector2(6, 12), Position = new Vector2(side * 18, 10), Color = new Color(0.5f, 0.35f, 0.2f) };
            _body.AddChild(claw);
        }

        // Health bar background
        _healthBg = new ColorRect { Size = new Vector2(60, 6), Position = new Vector2(-30, -22), Color = new Color(0.2f, 0.05f, 0.05f) };
        AddChild(_healthBg);

        _healthBar = new ColorRect { Size = new Vector2(60, 6), Position = new Vector2(-30, -22), Color = new Color(0.9f, 0.2f, 0.1f) };
        AddChild(_healthBar);
    }

    public override void _Process(double delta)
    {
        if (_health <= 0) return;
        var d = (float)delta;

        // Phase transition
        if (_health / MaxHp <= 0.5f && _phase == BossPhase.Phase1)
        {
            _phase = BossPhase.Phase2;
            EnterPhase2();
        }

        UpdatePhase(d);
        UpdateHealthBar();
        UpdateVisual(d);

        // Stun timer
        if (_stunTimer > 0)
        {
            _stunTimer = Mathf.Max(0, _stunTimer - d);
            if (_stunTimer <= 0) _isStunned = false;
        }
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_health <= 0) { Velocity = Vector2.Zero; MoveAndSlide(); return; }
        var d = (float)delta;

        if (_isStunned)
            Velocity = new Vector2(Velocity.X * 0.9f, Velocity.Y);
        else
            Velocity = new Vector2(Velocity.X, Mathf.Min(Velocity.Y + GameConstants.Gravity * d, GameConstants.TerminalVelocity));

        MoveAndSlide();

        if (!IsOnFloor() && !_isCharging)
            Velocity = new Vector2(Velocity.X * 0.98f, Velocity.Y);
    }

    // =========================================================================
    // AI Decision + Actions
    // =========================================================================
    private void UpdatePhase(float delta)
    {
        if (_isStunned) return;

        if (_player == null)
        {
            var players = GetTree().GetNodesInGroup("player");
            if (players.Count > 0)
                _player = players[0] as CharacterBody2D;
        }
        if (_player == null) return;

        // Face player
        float toPlayer = Mathf.Sign(_player.GlobalPosition.X - GlobalPosition.X);
        if (Mathf.Abs(toPlayer) > 0.01f)
            _body.Scale = new Vector2(toPlayer, 1);

        _actionTimer -= delta;
        if (_actionTimer <= 0)
            DecideAction();

        ExecuteAction(delta);
    }

    private void DecideAction()
    {
        float r = GD.Randf();
        float dist = _player != null ? GlobalPosition.DistanceTo(_player.GlobalPosition) : 500f;

        if (dist > 200)
            _currentAction = r < 0.6f ? "charge" : "jump";
        else if (_phase == BossPhase.Phase2 && r < 0.4f)
            _currentAction = "area_blast";
        else if (r < 0.5f)
            _currentAction = "charge";
        else
            _currentAction = "slam";

        _actionTimer = GD.Randf() * 1f + 0.5f;
    }

    private void ExecuteAction(float delta)
    {
        switch (_currentAction)
        {
            case "idle":        Velocity = new Vector2(0, Velocity.Y); break;
            case "charge":      ExecuteCharge();  break;
            case "jump":        ExecuteJump(delta);  break;
            case "slam":        ExecuteSlam();  break;
            case "area_blast":  ExecuteAreaBlast();  break;
        }
    }

    private void ExecuteCharge()
    {
        if (_player == null) return;
        if (!_isCharging)
        {
            _isCharging = true;
            _body.Color = new Color(0.3f, 0.1f, 0.1f);
        }
        float dir = Mathf.Sign(_player.GlobalPosition.X - GlobalPosition.X);
        Velocity = new Vector2(dir * _chargeSpeed, Velocity.Y);

        if (GlobalPosition.DistanceTo(_player.GlobalPosition) < 30)
        {
            _player.Call("take_damage", AttackDamage, this);
            EventBus.Instance.EmitSignal(EventBus.SignalName.ScreenShakeRequest, 5f, 0.1f);
            _isCharging = false;
            _body.Color = new Color(0.15f, 0.15f, 0.25f);
            _currentAction = "idle";
            _actionTimer = 1f;
        }
    }

    private void ExecuteJump(float delta)
    {
        if (IsOnFloor() && _jumpTimer <= 0)
        {
            Velocity = new Vector2(Velocity.X, -500);
            _jumpTimer = 0.5f;
        }
        else if (!IsOnFloor())
        {
            if (_player != null)
                Velocity = new Vector2(Mathf.Sign(_player.GlobalPosition.X - GlobalPosition.X) * 200, Velocity.Y);
            _jumpTimer -= delta;
        }
    }

    private void ExecuteSlam()
    {
        if (_player == null) return;
        float dir = Mathf.Sign(_player.GlobalPosition.X - GlobalPosition.X);
        Velocity = new Vector2(dir * _moveSpeed, Velocity.Y);

        if (GlobalPosition.DistanceTo(_player.GlobalPosition) < 26)
        {
            _player.Call("take_damage", AttackDamage * 0.6f, this);
            _currentAction = "idle";
            _actionTimer = 0.8f;
        }
    }

    private void ExecuteAreaBlast()
    {
        // Phase 2 — AOE blast with glow telegraph
        var flash = CreateTween();
        flash.TweenProperty(_body, "modulate", new Color(0.8f, 0.4f, 1f), 0.3f);
        flash.TweenProperty(_body, "modulate", Colors.White, 0.1f);

        GetTree().CreateTimer(0.3f).Timeout += () =>
        {
            if (_player != null && IsInstanceValid(_player) && GlobalPosition.DistanceTo(_player.GlobalPosition) < 100)
            {
                _player.Call("take_damage", AttackDamage * 1.5f, this);
                EventBus.Instance.EmitSignal(EventBus.SignalName.ScreenShakeRequest, 8f, 0.15f);
            }
        };
        _currentAction = "idle";
        _actionTimer = 2f;
    }

    // =========================================================================
    // Phase 2 Transition
    // =========================================================================
    private void EnterPhase2()
    {
        GD.Print("[Boss] Entering Phase 2!");
        _armor.Color = new Color(0.7f, 0.2f, 0.6f);
        foreach (var eye in _eyes)
            eye.Color = new Color(1f, 0.2f, 0.2f);
        _chargeSpeed = 500;
        _moveSpeed = 200;
        EventBus.Instance.EmitSignal(EventBus.SignalName.ScreenShakeRequest, 6f, 0.2f);
    }

    // =========================================================================
    // Visual Updates
    // =========================================================================
    private void UpdateHealthBar()
    {
        float ratio = _health / MaxHp;
        _healthBar.Size = new Vector2(60 * ratio, 6);
    }

    private void UpdateVisual(float delta)
    {
        // Eye flicker
        float t = Time.GetTicksMsec() / 1000f;
        for (int i = 0; i < _eyes.Count; i++)
            _eyes[i].Modulate = new Color(_eyes[i].Modulate.R, _eyes[i].Modulate.G, _eyes[i].Modulate.B, 0.5f + 0.5f * Mathf.Sin(t * 6f + i * 2f));

        // Recover from damage flash
        if (!_isStunned && _body.Modulate.R < 0.9f)
            _body.Modulate = _body.Modulate.Lerp(Colors.White, delta * 10f);
    }

    // =========================================================================
    // Damage / Death
    // =========================================================================
    public void TakeDamage(float amount, Node2D source)
    {
        if (_health <= 0) return;
        _health = Mathf.Max(0, _health - amount);

        if (source is CharacterBody2D)
            Velocity = new Vector2(Mathf.Sign(GlobalPosition.X - source.GlobalPosition.X) * (80f / KbResist), Velocity.Y);

        _isStunned = true;
        _stunTimer = 0.15f;
        _body.Modulate = Colors.White;
        _isCharging = false;

        EventBus.Instance.EmitSignal(EventBus.SignalName.DamageNumberRequest, amount, GlobalPosition + new Vector2(0, -20), false);
        GD.Print($"[Boss] HP: {_health}/{MaxHp}");

        if (_health <= 0) Die();
    }

    private void Die()
    {
        GD.Print("[Boss] Defeated!");
        EventBus.Instance.EmitSignal(EventBus.SignalName.EnemyKilled, this, GlobalPosition);
        EventBus.Instance.EmitSignal(EventBus.SignalName.BossDefeated);
        EventBus.Instance.EmitSignal(EventBus.SignalName.ScreenShakeRequest, 10f, 0.3f);
        EventBus.Instance.EmitSignal(EventBus.SignalName.TimeScaleRequest, 0.3f, 0.3f);

        var t = CreateTween();
        t.TweenProperty(_body, "modulate:a", 0.0, 1.0);
        t.TweenCallback(Callable.From(QueueFree));
    }
}
