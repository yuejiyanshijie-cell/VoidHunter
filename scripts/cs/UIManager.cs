using Godot;

namespace VoidHunter;

/// <summary>
/// UI Manager — health bar, skill cooldowns, game-over screen.
/// Safely discovers UI elements via recursive search (no hard paths).
/// </summary>
public partial class UIManager : CanvasLayer
{
    private ProgressBar _healthBar;
    private Label _healthLabel;
    private Label _skill1Label;
    private Label _skill2Label;
    private TextureRect _skill1Icon;
    private TextureRect _skill2Icon;
    private Label _gameOverLabel;

    public override void _Ready()
    {
        FindUIElements();
        if (_healthBar != null)
        {
            _healthBar.MaxValue = GameConstants.PlayerMaxHealth;
            _healthBar.Value = GameConstants.PlayerMaxHealth;
        }
        if (_healthLabel != null)
            _healthLabel.Text = Mathf.CeilToInt(GameConstants.PlayerMaxHealth).ToString();

        EventBus.Instance.PlayerHealthChanged += OnHealthChanged;
        EventBus.Instance.SkillCooldownUpdated += OnCooldownUpdated;
        EventBus.Instance.PlayerDied += OnPlayerDied;
    }

    // =========================================================================
    // UI Element Discovery — recursive, no hard paths
    // =========================================================================
    private void FindUIElements()
    {
        var hBox = FindChildOfType<HBoxContainer>(this);
        if (hBox == null)
        {
            GD.PushWarning("[UI] HBoxContainer not found — UI disabled");
            return;
        }

        // First VBoxContainer = health area
        VBoxContainer healthVBox = null;
        VBoxContainer skillsVBox = null;

        foreach (var child in hBox.GetChildren())
        {
            if (child is VBoxContainer vb)
            {
                if (healthVBox == null)
                    healthVBox = vb;
                else
                    skillsVBox = vb;
            }
        }

        if (healthVBox != null)
        {
            _healthBar = FindChildOfType<ProgressBar>(healthVBox);
            _healthLabel = FindChildOfType<Label>(healthVBox);
        }

        if (skillsVBox != null)
        {
            var icons = new System.Collections.Generic.List<TextureRect>();
            var labels = new System.Collections.Generic.List<Label>();
            foreach (var child in skillsVBox.GetChildren())
            {
                foreach (var sub in ((Node)child).GetChildren())
                {
                    if (sub is TextureRect tr && icons.Count < 2) icons.Add(tr);
                    if (sub is Label lb && labels.Count < 2) labels.Add(lb);
                }
            }
            if (icons.Count >= 2) { _skill1Icon = icons[0]; _skill2Icon = icons[1]; }
            if (labels.Count >= 2) { _skill1Label = labels[0]; _skill2Label = labels[1]; }
        }
    }

    /// <summary>Recursively find the first descendant matching type T.</summary>
    private static T FindChildOfType<T>(Node parent) where T : Node
    {
        foreach (var child in parent.GetChildren())
        {
            if (child is T match) return match;
            var found = FindChildOfType<T>(child);
            if (found != null) return found;
        }
        return null;
    }

    // =========================================================================
    // Signal Handlers
    // =========================================================================
    private void OnHealthChanged(float current, float maxHp)
    {
        if (_healthBar != null)
        {
            _healthBar.Value = current;
            _healthBar.MaxValue = maxHp;
            _healthBar.Modulate = current / maxHp < 0.3f ? Colors.Red : Colors.White;
        }
        if (_healthLabel != null)
            _healthLabel.Text = Mathf.CeilToInt(current).ToString();
    }

    private void OnCooldownUpdated(int skillId, float remaining, float total)
    {
        var label = skillId == 1 ? _skill1Label : _skill2Label;
        var icon = skillId == 1 ? _skill1Icon : _skill2Icon;

        if (label != null)
            label.Text = remaining > 0 ? Mathf.CeilToInt(remaining).ToString() : "";
        if (icon != null)
            icon.Modulate = remaining > 0 ? new Color(0.5f, 0.5f, 0.5f, 1f) : Colors.White;
    }

    private void OnPlayerDied()
    {
        if (_gameOverLabel != null) return;
        _gameOverLabel = new Label
        {
            Text = "YOU DIED",
            AnchorsPreset = (int)LayoutPreset.Center
        };
        _gameOverLabel.AddThemeFontSizeOverride("font_size", 48);
        _gameOverLabel.AddThemeColorOverride("font_color", Colors.Red);
        AddChild(_gameOverLabel);
        GD.Print("[UI] Game Over displayed");
    }
}
