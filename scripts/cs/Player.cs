using Godot;
using Godot.Collections;

namespace VoidHunter;

public partial class Player : CharacterBody2D
{
    public enum State { Idle, Run, Jump, Fall, Dash, WallSlide, Attacking, Dodging, Stunned, Dead }

    [Export] public float Speed { get; set; } = GameConstants.PlayerSpeed;
    [Export] public float JumpVelocity { get; set; } = GameConstants.JumpVelocity;
    [Export] public float DoubleJumpVelocity { get; set; } = GameConstants.DoubleJumpVelocity;

    // State
    public State CurrentState { get; private set; } = State.Idle;
    public float FacingDirection { get; private set; } = 1f;

    // Movement
    private float _inputDir;
    private bool _hasDoubleJump = true;
    private bool _isDashing;
    private float _dashTimer;
    private float _dashCd;
    private float _coyoteTimer;
    private float _jumpBuffer;
    private float _wallJumpCd;

    // Combat
    private bool _isAttacking;
    private int _comboCount;
    private bool _canAttack = true;
    private bool _isDodging;
    private float _dodgeCd;
    private float _atkTimer;
    private float _comboWindow;
    private float _currentDmg;
    private bool _bufferCombo;
    private readonly Array<Node2D> _hitList = new();

    // Heavy attack
    private bool _isHolding;
    private float _holdTimer;
    private int _heavyStage; // 0=none, 1=charge, 2=windup, 3=active, 4=recovery

    // Nodes
    private RayCast2D _wallDetector;
    private Area2D _hurtbox;
    private ColorRect _body;
    private ColorRect _sword;
    private ColorRect _eye;

    // Timing
    private const float ComboWindow = 0.55f;
    private const float Atk1Time = 0.20f;
    private const float Atk2Time = 0.24f;
    private const float Atk3Time = 0.32f;
    private const float HeavyCharge = 0.35f;
    private const float HeavyWindup = 0.15f;
    private const float HeavyActive = 0.15f;
    private const float HeavyRecovery = 0.2f;
    private const float DownstrikeTime = 0.25f;

    public override void _Ready()
    {
        _wallDetector = GetNodeOrNull<RayCast2D>("WallDetector");
        _hurtbox = GetNodeOrNull<Area2D>("Hurtbox");
        EventBus.Instance.PlayerDamaged += OnDamaged;
        EventBus.Instance.PlayerDied += OnDied;
        CreateVisual();
    }

    public override void _Process(double delta)
    {
        if (CurrentState == State.Dead) return;
        var d = (float)delta;
        UpdateTimers(d);
        UpdateAttack(d);
        UpdateVisuals(d);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (CurrentState == State.Dead) { Velocity = Vector2.Zero; MoveAndSlide(); return; }
        var d = (float)delta;
        HandleInput();
        HandleGravity(d);
        HandleMovement();
        MoveAndSlide();
        UpdateState();
        CheckGround();
    }

    private void CreateVisual()
    {
        _body = new ColorRect { Size = new Vector2(16, 28), Position = new Vector2(-8, -30), Color = new Color(0.06f, 0.05f, 0.1f) };
        AddChild(_body);
        var head = new ColorRect { Size = new Vector2(10, 6), Position = new Vector2(-5, -36), Color = new Color(0.1f, 0.1f, 0.16f) };
        _body.AddChild(head);
        _eye = new ColorRect { Size = new Vector2(4, 2), Position = new Vector2(-2, -34), Color = new Color(0, 0.85f, 1) };
        _body.AddChild(_eye);
        _sword = new ColorRect { Size = new Vector2(2, 13), Position = new Vector2(8, -29), Color = new Color(0.7f, 0.7f, 0.85f) };
        AddChild(_sword);
    }

    private void UpdateVisuals(float d)
    {
        if (_body == null) return;
        _body.Scale = new Vector2(FacingDirection, 1);
        _sword.Scale = new Vector2(FacingDirection, 1);
        if (_isDashing) { _body.Modulate = new Color(0.6f, 0.4f, 1f, 0.85f); _sword.Modulate = new Color(0.85f, 0.65f, 1f, 0.85f); }
        else { _body.Modulate = Colors.White; _sword.Modulate = Colors.White; }
        var blink = Time.GetTicksMsec() % 1000 * 0.001f % 0.08f < 0.04f;
        _body.Visible = !(_isDodging && blink); _sword.Visible = !(_isDodging && blink);
        if (CurrentState == State.Stunned) _body.Color = new Color(0.35f, 0.03f, 0.03f);
        else _body.Color = new Color(0.06f, 0.05f, 0.1f);
        if (CurrentState == State.Run) _body.Position = new Vector2(_body.Position.X, -30 + Mathf.Sin(Time.GetTicksMsec() * 0.012f) * 1.2f);
        else _body.Position = new Vector2(_body.Position.X, -30);
    }

    private void UpdateTimers(float d)
    {
        _dashTimer = Mathf.MoveToward(_dashTimer, 0, d);
        if (_dashTimer <= 0 && _isDashing) EndDash();
        _dashCd = Mathf.MoveToward(_dashCd, 0, d);
        _dodgeCd = Mathf.MoveToward(_dodgeCd, 0, d);
        _wallJumpCd = Mathf.MoveToward(_wallJumpCd, 0, d);
        if (_jumpBuffer > 0) { _jumpBuffer -= d; if (IsOnFloor() || _coyoteTimer > 0) { PerformJump(); _jumpBuffer = 0; } }
        if (_coyoteTimer > 0 && !IsOnFloor()) _coyoteTimer -= d;
        else if (IsOnFloor()) _coyoteTimer = GameConstants.CoyoteTime;
    }

    private void HandleInput()
    {
        if (CurrentState is State.Dead or State.Stunned) return;
        _inputDir = Input.GetAxis("move_left", "move_right");
        if (_inputDir != 0) FacingDirection = _inputDir;
        if (Input.IsActionJustPressed("jump")) { _jumpBuffer = GameConstants.JumpBuffer; TryJump(); }
        if (Input.IsActionJustReleased("jump") && Velocity.Y < 0) Velocity = new Vector2(Velocity.X, Velocity.Y * 0.5f);
        if (Input.IsActionJustPressed("dash") && _dashTimer <= 0 && _dashCd <= 0) StartDash();
        if (Input.IsActionJustPressed("dodge") && _dodgeCd <= 0) StartDodge();
        if (Input.IsActionJustPressed("attack")) OnAttackPress();
        if (Input.IsActionJustReleased("attack")) OnAttackRelease();
        if (Input.IsActionJustPressed("skill1")) CastSkill(1);
        if (Input.IsActionJustPressed("skill2")) CastSkill(2);
    }

    private void UpdateState()
    {
        if (CurrentState is State.Dead or State.Dodging or State.Stunned) return;
        if (_isDashing) CurrentState = State.Dash;
        else if (IsWallSliding()) CurrentState = State.WallSlide;
        else if (_isAttacking || _heavyStage > 0) CurrentState = State.Attacking;
        else if (!IsOnFloor()) CurrentState = Velocity.Y < 0 ? State.Jump : State.Fall;
        else if (Mathf.Abs(Velocity.X) > 10) CurrentState = State.Run;
        else CurrentState = State.Idle;
    }

    private void HandleGravity(float d)
    {
        if (_isDashing) return;
        if (IsWallSliding())
            Velocity = new Vector2(Velocity.X, Mathf.Min(Velocity.Y + GameConstants.Gravity * 0.3f * d, GameConstants.WallSlideSpeed));
        else
            Velocity = new Vector2(Velocity.X, Mathf.Min(Velocity.Y + GameConstants.Gravity * d, GameConstants.TerminalVelocity));
    }

    private void HandleMovement()
    {
        if (_isDashing) Velocity = new Vector2(FacingDirection * GameConstants.DashSpeed, Velocity.Y);
        else if (IsWallSliding()) Velocity = new Vector2(_inputDir * Speed * 0.3f, Velocity.Y);
        else if (_isAttacking) Velocity = new Vector2(_inputDir * Speed * 0.5f, Velocity.Y);
        else Velocity = new Vector2(_inputDir * Speed, Velocity.Y);
    }

    private void CheckGround() { if (IsOnFloor()) { _hasDoubleJump = true; _coyoteTimer = GameConstants.CoyoteTime; } }
    private bool IsWallSliding() =>
        !IsOnFloor() && _wallJumpCd <= 0 && _inputDir != 0 && IsOnWall() && _wallDetector != null && _wallDetector.IsColliding();

    // --- Jump ---
    private void TryJump()
    {
        if (IsWallSliding()) PerformWallJump();
        else if (IsOnFloor() || _coyoteTimer > 0) { PerformJump(); _coyoteTimer = 0; }
        else if (!IsOnFloor() && _hasDoubleJump) PerformDoubleJump();
    }
    private void PerformJump() { Velocity = new Vector2(Velocity.X, JumpVelocity); _jumpBuffer = 0; SpawnJumpFx(); }
    private void PerformDoubleJump() { Velocity = new Vector2(Velocity.X, DoubleJumpVelocity); _hasDoubleJump = false; SpawnJumpFx(); }
    private void PerformWallJump() { Velocity = new Vector2(-FacingDirection * GameConstants.WallJumpH, GameConstants.WallJumpV); _wallJumpCd = 0.2f; SpawnJumpFx(); }

    private void SpawnJumpFx()
    {
        var ring = new ColorRect { Size = new Vector2(20, 4), Position = GlobalPosition + new Vector2(-10, 10), Color = new Color(0.3f, 0.5f, 1f, 0.6f) };
        GetParent().AddChild(ring);
        var t = CreateTween(); t.TweenProperty(ring, "size", new Vector2(40, 1), 0.25f);
        t.Parallel().TweenProperty(ring, "color:a", 0f, 0.25f); t.TweenCallback(Callable.From(ring.QueueFree));
    }

    // --- Dash ---
    private void StartDash() { _isDashing = true; _dashTimer = GameConstants.DashDuration; _dashCd = GameConstants.DashCooldown; }
    private void EndDash() { _isDashing = false; Velocity = new Vector2(_inputDir * Speed, Velocity.Y); }

    // --- Attack ---
    private void OnAttackPress()
    {
        if (!_canAttack || _isDashing) return;
        if (!IsOnFloor()) { StartDownstrike(); return; }
        if (_heavyStage > 0) return;
        if (_isAttacking) { _bufferCombo = true; return; }
        _isHolding = true; _holdTimer = 0;
        _comboCount = _comboWindow > 0 ? (_comboCount + 1) % 3 : 0;
        StartLightAttack();
    }

    private void OnAttackRelease()
    {
        if (!_isHolding) return; _isHolding = false;
        if (_holdTimer >= HeavyCharge && IsOnFloor() && _heavyStage == 0)
        { if (_isAttacking) CancelAttack(); StartHeavyAttack(); }
    }

    private void StartLightAttack()
    {
        _isAttacking = true; _canAttack = false; _bufferCombo = false; _hitList.Clear();
        _atkTimer = _comboCount switch { 0 => Atk1Time, 1 => Atk2Time, _ => Atk3Time };
        _currentDmg = _comboCount switch { 0 => GameConstants.AtkLight, 1 => GameConstants.AtkLight * 1.25f, _ => GameConstants.AtkLight * 1.8f };
        _comboWindow = ComboWindow;
        var dash = CreateTween(); dash.TweenProperty(this, "velocity:x", FacingDirection * 80, 0.06f);
        dash.TweenProperty(this, "velocity:x", _inputDir * Speed * 0.5f, 0.1f);
        GetTree().CreateTimer(0.06f + _comboCount * 0.02f).Timeout += AttackHitCheck;
        StartSlashAnim();
    }

    private void StartSlashAnim()
    {
        var colors = new Color[] { new(0.7f, 0.8f, 1f), new(0.5f, 0.7f, 1f), new(0.7f, 0.35f, 1f) };
        _sword.Color = colors[_comboCount];
        var s = CreateTween(); s.TweenProperty(_sword, "position:x", 8 + FacingDirection * 4, 0.03f); s.TweenProperty(_sword, "position:x", 8, 0.08f);
        var b = CreateTween(); b.TweenProperty(_body, "rotation", FacingDirection * 0.1f, 0.04f); b.TweenProperty(_body, "rotation", 0f, 0.12f);
        // Slash arc
        var arc = new ColorRect { Size = new Vector2(24, 16), Position = GlobalPosition + new Vector2(FacingDirection * 10, -24),
            PivotOffset = new Vector2(0, 8), Rotation = FacingDirection * -0.3f, Color = new Color(0.5f, 0.6f, 1f, 0.5f), ZIndex = 4 };
        GetParent().AddChild(arc);
        var a = CreateTween(); a.TweenProperty(arc, "rotation", FacingDirection * 0.5f, 0.18f);
        a.Parallel().TweenProperty(arc, "color:a", 0f, 0.2f); a.Parallel().TweenProperty(arc, "size:x", 32f, 0.15f); a.TweenCallback(Callable.From(arc.QueueFree));
    }

    private void AttackHitCheck()
    {
        if (!_isAttacking || _heavyStage > 0) return;
        int hits = 0;
        foreach (var enemy in GetTree().GetNodesInGroup("enemy"))
        {
            if (!IsInstanceValid(enemy) || _hitList.Contains(enemy)) continue;
            if (!enemy.HasMethod("take_damage")) continue;
            var n = enemy as Node2D; if (n == null) continue;
            var dist = GlobalPosition.DistanceTo(n.GlobalPosition);
            if (dist < 30 && Mathf.Sign(n.GlobalPosition.X - GlobalPosition.X) == FacingDirection)
            {
                n.Call("take_damage", _currentDmg, this); _hitList.Add(n); hits++;
                EventBus.Instance.EmitSignal(SignalName.DamageNumberRequest, _currentDmg, n.GlobalPosition, _comboCount == 2);
                SpawnHitFx(n.GlobalPosition);
            }
        }
        if (hits > 0) { EventBus.Instance.EmitSignal(SignalName.ScreenShakeRequest, 2f + _comboCount * 2, 0.05f); EventBus.Instance.EmitSignal(SignalName.TimeScaleRequest, 0.8f, 0.03f); }
        else SpawnWhiffFx(GlobalPosition + new Vector2(FacingDirection * 20, -15));
    }

    private void StartHeavyAttack()
    {
        _heavyStage = 1; _isAttacking = true; _canAttack = false; _atkTimer = HeavyWindup; _currentDmg = GameConstants.AtkHeavy; _comboWindow = 0;
        _body.Color = new Color(0.25f, 0.1f, 0.4f); _sword.Color = new Color(0.9f, 0.25f, 1f);
        var pulse = CreateTween().SetLoops(); pulse.TweenProperty(_body, "scale", new Vector2(1.12f, 1.12f), 0.15f); pulse.TweenProperty(_body, "scale", Vector2.One, 0.15f);
    }

    private void StartDownstrike()
    {
        _isAttacking = true; _canAttack = false; _hitList.Clear(); _atkTimer = DownstrikeTime; _currentDmg = GameConstants.AtkDownstrike; _comboWindow = 0;
        Velocity = new Vector2(_inputDir * Speed * 0.25f, 550); _sword.Color = new Color(0.65f, 0.75f, 1f);
        GetTree().CreateTimer(0.04f).Timeout += AttackHitCheck;
    }
    private void UpdateAttack(float d)
    {
        if (_isHolding) _holdTimer += d;
        if (_heavyStage > 0) { UpdateHeavyStage(d); return; }
        if (!_isAttacking) return;
        _atkTimer -= d;
        if (_atkTimer <= 0) OnLightAttackEnd();
        _comboWindow = Mathf.Max(0, _comboWindow - d);
    }

    private void UpdateHeavyStage(float d)
    {
        _atkTimer -= d; if (_atkTimer > 0) return;
        switch (_heavyStage)
        {
            case 1: _heavyStage = 2; _atkTimer = HeavyWindup; _body.Scale = new Vector2(1.15f, 1.15f); break;
            case 2: _heavyStage = 3; _atkTimer = HeavyActive; HeavyHitCheck(); break;
            case 3: _heavyStage = 4; _atkTimer = HeavyRecovery; _body.Scale = Vector2.One; _body.Color = new Color(0.06f, 0.05f, 0.1f); _sword.Color = new Color(0.7f, 0.7f, 0.85f); break;
            case 4: _heavyStage = 0; _isAttacking = false; ResetAttack(); break;
        }
    }

    private void HeavyHitCheck()
    {
        int hit = 0;
        foreach (var enemy in GetTree().GetNodesInGroup("enemy"))
        {
            if (!IsInstanceValid(enemy) || _hitList.Contains(enemy)) continue;
            if (!enemy.HasMethod("take_damage")) continue;
            var n = enemy as Node2D; if (n == null) continue;
            if (GlobalPosition.DistanceTo(n.GlobalPosition) < 50)
            {
                n.Call("take_damage", _currentDmg, this); _hitList.Add(n); hit++;
                if (enemy is CharacterBody2D eb) eb.Velocity = new Vector2(eb.Velocity.X + Mathf.Sign(n.GlobalPosition.X - GlobalPosition.X) * 500, eb.Velocity.Y);
                EventBus.Instance.EmitSignal(SignalName.DamageNumberRequest, _currentDmg, n.GlobalPosition, true);
                SpawnHitFx(n.GlobalPosition);
            }
        }
        if (hit > 0) { EventBus.Instance.EmitSignal(SignalName.ScreenShakeRequest, 6f, 0.12f); EventBus.Instance.EmitSignal(SignalName.TimeScaleRequest, 0.5f, 0.06f); }
    }

    private void OnLightAttackEnd()
    {
        if (_bufferCombo) { _bufferCombo = false; _comboCount = (_comboCount + 1) % 3; StartLightAttack(); return; }
        _isAttacking = false; _sword.Color = new Color(0.7f, 0.7f, 0.85f);
        if (_comboWindow > 0) { _canAttack = true; GetTree().CreateTimer(_comboWindow).Timeout += ResetIfInactive; }
        else ResetAttack();
        if (CurrentState == State.Attacking) CurrentState = State.Idle;
    }

    private void ResetIfInactive() { if (!_isAttacking && _comboWindow <= 0) ResetAttack(); }
    private void ResetAttack() { _comboCount = 0; _comboWindow = 0; _bufferCombo = false; _canAttack = true; if (CurrentState == State.Attacking) CurrentState = State.Idle; }
    private void CancelAttack() { _isAttacking = false; _heavyStage = 0; _isHolding = false; _bufferCombo = false; _hitList.Clear(); _body.Scale = Vector2.One; _body.Color = new Color(0.06f, 0.05f, 0.1f); _sword.Color = new Color(0.7f, 0.7f, 0.85f); ResetAttack(); }

    // --- Dodge ---
    private void StartDodge()
    {
        if (_isAttacking) CancelAttack();
        _isDodging = true; _dodgeCd = GameConstants.DodgeCooldown; CurrentState = State.Dodging;
        if (_hurtbox != null) _hurtbox.Monitoring = false;
        var dir = _inputDir != 0 ? _inputDir : -FacingDirection;
        Velocity = new Vector2(dir * 250, -80);
        GetTree().CreateTimer(GameConstants.DodgeDuration).Timeout += EndDodge;
    }
    private void EndDodge() { _isDodging = false; if (_hurtbox != null) _hurtbox.Monitoring = true; CurrentState = State.Idle; }

    // --- Skills ---
    private void CastSkill(int id)
    {
        if (!GameManager.Instance.UseSkill(id)) return;
        if (_isAttacking) CancelAttack();
        if (id == 1) SkillMechBlast(); else SkillVoidSlash();
    }

    private void SkillMechBlast()
    {
        _canAttack = false; _isAttacking = true;
        var wave = new ColorRect { Size = new Vector2(8, 20), Position = GlobalPosition + new Vector2(FacingDirection * 12, -20), Color = new Color(0.3f, 0.5f, 1f, 0.7f), ZIndex = 5 };
        GetParent().AddChild(wave);
        var w = CreateTween(); w.TweenProperty(wave, "size:x", 80f, 0.2f); w.Parallel().TweenProperty(wave, "position:x", GlobalPosition.X + FacingDirection * 80, 0.2f);
        w.Parallel().TweenProperty(wave, "color:a", 0f, 0.25f); w.TweenCallback(Callable.From(wave.QueueFree));
        GetTree().CreateTimer(0.1f).Timeout += () => {
            foreach (var enemy in GetTree().GetNodesInGroup("enemy"))
            {
                if (!IsInstanceValid(enemy) || !enemy.HasMethod("take_damage")) continue;
                var n = enemy as Node2D; if (n == null) continue;
                if (GlobalPosition.DistanceTo(n.GlobalPosition) < GameConstants.Skill1Range && Mathf.Sign(n.GlobalPosition.X - GlobalPosition.X) == FacingDirection)
                {
                    n.Call("take_damage", GameConstants.Skill1Damage, this);
                    if (enemy is CharacterBody2D eb) eb.Velocity = new Vector2(eb.Velocity.X + FacingDirection * GameConstants.Skill1Knockback, eb.Velocity.Y);
                    EventBus.Instance.EmitSignal(SignalName.DamageNumberRequest, GameConstants.Skill1Damage, n.GlobalPosition, false);
                    SpawnHitFx(n.GlobalPosition);
                }
            }
            EventBus.Instance.EmitSignal(SignalName.ScreenShakeRequest, 4f, 0.08f);
        };
        GetTree().CreateTimer(0.3f).Timeout += () => { _isAttacking = false; _canAttack = true; };
    }

    private void SkillVoidSlash()
    {
        _canAttack = false; _isAttacking = true;
        for (int i = 0; i < 3; i++)
            GetTree().CreateTimer(i * 0.08f).Timeout += () => {
                var ring = new ColorRect { Size = new Vector2(10, 10), Position = GlobalPosition + new Vector2(-5, -20), Color = new Color(0.6f, 0.3f, 1f, 0.6f), ZIndex = 5 };
                GetParent().AddChild(ring);
                var r = CreateTween(); r.TweenProperty(ring, "size", new Vector2(70, 70), 0.35f);
                r.Parallel().TweenProperty(ring, "position", GlobalPosition + new Vector2(-35, -45), 0.35f);
                r.Parallel().TweenProperty(ring, "color:a", 0f, 0.35f); r.TweenCallback(Callable.From(ring.QueueFree));
            };
        GetTree().CreateTimer(0.2f).Timeout += () => {
            int hit = 0;
            foreach (var enemy in GetTree().GetNodesInGroup("enemy"))
            {
                if (!IsInstanceValid(enemy) || !enemy.HasMethod("take_damage")) continue;
                var n = enemy as Node2D; if (n == null) continue;
                if (GlobalPosition.DistanceTo(n.GlobalPosition) < GameConstants.Skill2Range)
                { n.Call("take_damage", GameConstants.Skill2Damage, this); hit++; EventBus.Instance.EmitSignal(SignalName.DamageNumberRequest, GameConstants.Skill2Damage, n.GlobalPosition, false); SpawnHitFx(n.GlobalPosition); }
            }
            if (hit > 0) { EventBus.Instance.EmitSignal(SignalName.ScreenShakeRequest, 5f, 0.1f); EventBus.Instance.EmitSignal(SignalName.TimeScaleRequest, 0.6f, 0.05f); }
        };
        GetTree().CreateTimer(0.45f).Timeout += () => { _isAttacking = false; _canAttack = true; };
    }

    // --- Fx ---
    private void SpawnHitFx(Vector2 pos)
    {
        for (int i = 0; i < 5; i++)
        {
            var s = new ColorRect { Size = new Vector2(3, 3), Position = pos + new Vector2(GD.Randf() * 16 - 8, GD.Randf() * 16 - 8), Color = new Color(0.8f, 0.85f, 1f) };
            GetParent().AddChild(s);
            var t = CreateTween(); t.TweenProperty(s, "position", s.Position + new Vector2(GD.Randf() * 120 - 60, GD.Randf() * 80 - 40), 0.25f);
            t.Parallel().TweenProperty(s, "color:a", 0f, 0.25f); t.Parallel().TweenProperty(s, "size", Vector2.Zero, 0.25f); t.TweenCallback(Callable.From(s.QueueFree));
        }
    }
    private void SpawnWhiffFx(Vector2 pos)
    {
        var swipe = new ColorRect { Size = new Vector2(18, 3), Position = pos, Color = new Color(0.4f, 0.5f, 1f, 0.35f) };
        GetParent().AddChild(swipe);
        var t = CreateTween(); t.TweenProperty(swipe, "position:x", pos.X + FacingDirection * 30, 0.15f); t.Parallel().TweenProperty(swipe, "color:a", 0f, 0.2f); t.TweenCallback(Callable.From(swipe.QueueFree));
    }

    // --- Damage ---
    private void OnDamaged(float amount, Node2D source)
    {
        CancelAttack(); CurrentState = State.Stunned;
        if (source != null) Velocity = (GlobalPosition - source.GlobalPosition).Normalized() * 300;
        GetTree().CreateTimer(0.3f).Timeout += () => CurrentState = State.Idle;
    }
    private void OnDied() { CurrentState = State.Dead; Velocity = Vector2.Zero; }
    public void TakeDamage(float amount, Node2D source) { if (!_isDodging && !_isDashing) GameManager.Instance.DamagePlayer(amount, source); }
}
