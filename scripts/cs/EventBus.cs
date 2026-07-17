using Godot;
using Godot.Collections;

namespace VoidHunter;

/// <summary>Global event bus — decoupled signalling between modules.</summary>
public partial class EventBus : Node
{
    public static EventBus Instance { get; private set; }

    // Player
    [Signal] public delegate void PlayerDamagedEventHandler(float amount, Node2D source);
    [Signal] public delegate void PlayerDiedEventHandler();
    [Signal] public delegate void PlayerHealthChangedEventHandler(float current, float max);
    [Signal] public delegate void PlayerSkillUsedEventHandler(int skillId);
    [Signal] public delegate void SkillCooldownUpdatedEventHandler(int skillId, float remaining, float total);

    // Combat
    [Signal] public delegate void EnemyKilledEventHandler(Node2D enemy, Vector2 position);
    [Signal] public delegate void DamageNumberRequestEventHandler(float amount, Vector2 pos, bool crit);
    [Signal] public delegate void HitEffectRequestEventHandler(Vector2 pos, string type);

    // Game flow
    [Signal] public delegate void LevelLoadedEventHandler(string levelName);
    [Signal] public delegate void BossFightStartedEventHandler(Node2D boss);
    [Signal] public delegate void BossDefeatedEventHandler();

    // Camera
    [Signal] public delegate void ScreenShakeRequestEventHandler(float amplitude, float duration);
    [Signal] public delegate void TimeScaleRequestEventHandler(float scale, float duration);

    public override void _Ready()
    {
        Instance = this;
    }
}
