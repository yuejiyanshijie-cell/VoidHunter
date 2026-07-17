using Godot;

namespace VoidHunter;

/// <summary>Global game manager — state, health, skill cooldowns.</summary>
public partial class GameManager : Node
{
    public static GameManager Instance { get; private set; }

    public enum GameState { MainMenu, Playing, Paused, GameOver, BossFight, Victory }
    public GameState CurrentState { get; set; } = GameState.MainMenu;

    public float PlayerHealth { get; set; } = GameConstants.PlayerMaxHealth;
    public float PlayerMaxHealth => GameConstants.PlayerMaxHealth;

    private readonly float[] _cooldowns = new float[3];
    private readonly float[] _cooldownTotals = { 0f, GameConstants.Skill1Cooldown, GameConstants.Skill2Cooldown };

    public override void _Ready()
    {
        Instance = this;
        ProcessMode = ProcessModeEnum.Always;
    }

    public override void _Process(double delta)
    {
        if (CurrentState == GameState.Playing || CurrentState == GameState.BossFight)
        {
            var d = (float)delta;
            for (int i = 1; i <= 2; i++)
            {
                if (_cooldowns[i] > 0)
                {
                    _cooldowns[i] = Mathf.Max(0, _cooldowns[i] - d);
                    EventBus.Instance.EmitSignal(SignalName.SkillCooldownUpdated, i, _cooldowns[i], _cooldownTotals[i]);
                }
            }
        }
    }

    public void DamagePlayer(float amount, Node2D source = null)
    {
        PlayerHealth = Mathf.Max(0, PlayerHealth - amount);
        EventBus.Instance.EmitSignal(SignalName.PlayerHealthChanged, PlayerHealth, PlayerMaxHealth);
        EventBus.Instance.EmitSignal(SignalName.PlayerDamaged, amount, source);
        if (PlayerHealth <= 0)
            EventBus.Instance.EmitSignal(SignalName.PlayerDied);
    }

    public void HealPlayer(float amount)
    {
        PlayerHealth = Mathf.Min(PlayerMaxHealth, PlayerHealth + amount);
        EventBus.Instance.EmitSignal(SignalName.PlayerHealthChanged, PlayerHealth, PlayerMaxHealth);
    }

    public bool UseSkill(int id)
    {
        if (_cooldowns[id] > 0) return false;
        _cooldowns[id] = _cooldownTotals[id];
        EventBus.Instance.EmitSignal(SignalName.PlayerSkillUsed, id);
        return true;
    }
}
