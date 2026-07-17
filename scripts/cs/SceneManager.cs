using Godot;

namespace VoidHunter;

/// <summary>
/// Scene manager — spawns player, enemies, UI. Coordinates camera and combat system.
/// Root node of main_level.tscn.
/// </summary>
public partial class SceneManager : Node2D
{
    [Export] public PackedScene PlayerScene { get; set; }

    private Marker2D _playerSpawn;
    private Camera2D _camera;
    private CombatSystem _combatSystem;
    private Node _enemyContainer;

    public override void _Ready()
    {
        _playerSpawn = GetNodeOrNull<Marker2D>("PlayerSpawn");
        _camera = GetNodeOrNull<Camera2D>("Camera2D");
        _combatSystem = GetNodeOrNull<CombatSystem>("CombatSystem");
        _enemyContainer = GetNodeOrNull<Node>("EnemyContainer");

        // Level terrain is built by LevelBuilder node in this scene
        if (_combatSystem != null)
            _combatSystem.Initialize(this, _camera);

        SpawnPlayer();
        SpawnTestEnemies();
        EventBus.Instance.EmitSignal(EventBus.SignalName.LevelLoaded, "demo_level");
    }

    private void SpawnPlayer()
    {
        if (PlayerScene == null)
        {
            GD.PushError("Player scene not assigned!");
            return;
        }

        var player = PlayerScene.Instantiate<CharacterBody2D>();
        player.GlobalPosition = _playerSpawn != null ? _playerSpawn.GlobalPosition : new Vector2(100, 420);
        AddChild(player);
        player.AddToGroup("player");

        // Set camera follow target if camera has that property
        if (_camera is CameraController cc)
            cc.FollowTarget = player;
        else if (_camera != null && _camera.HasMethod("set"))
            _camera.Set("follow_target", player);

        // Load and add UI
        var uiScene = GD.Load<PackedScene>("res://scenes/ui.tscn");
        if (uiScene != null)
        {
            var ui = uiScene.Instantiate<CanvasLayer>();
            AddChild(ui);
        }
    }

    private void SpawnTestEnemies()
    {
        var bugScene = GD.Load<PackedScene>("res://scenes/enemy_bug.tscn");
        var guardScene = GD.Load<PackedScene>("res://scenes/enemy_guard.tscn");
        var bossScene = GD.Load<PackedScene>("res://scenes/enemy_boss.tscn");

        if (_enemyContainer == null) return;

        // Bug swarm
        SpawnEnemy(bugScene, new Vector2(350, 440));
        SpawnEnemy(bugScene, new Vector2(500, 440));
        SpawnEnemy(bugScene, new Vector2(650, 440));

        // Guards (ranged)
        SpawnEnemy(guardScene, new Vector2(900, 440));
        SpawnEnemy(guardScene, new Vector2(1300, 430));

        // Boss
        SpawnEnemy(bossScene, new Vector2(1700, 430));
    }

    private void SpawnEnemy(PackedScene scene, Vector2 position)
    {
        if (scene == null) return;
        var enemy = scene.Instantiate<CharacterBody2D>();
        enemy.GlobalPosition = position;
        _enemyContainer.AddChild(enemy);
    }

    public void TransitionToScene(string scenePath)
    {
        GetTree().ChangeSceneToFile(scenePath);
    }
}
