using Godot;

namespace VoidHunter;

// Headless builder for enemy_guard.tscn (7 nodes).
// Run: godot --headless --script res://scripts/cs/BuildEnemyGuard.cs
public partial class BuildEnemyGuard : Node
{
    public override void _Ready() => Run();

    static readonly RectangleShape2D GuardCollision = new() { Size = new(22, 22) };
    static readonly CircleShape2D    GuardHurtbox   = new() { Radius = 14f };
    static readonly RectangleShape2D GuardHitbox    = new() { Size = new(28, 16) };

    void Run()
    {
        GD.Print("[BuildEnemyGuard] Building enemy_guard.tscn ...");
        var root = new CharacterBody2D
            { Name = "EnemyGuard", CollisionLayer = 2, CollisionMask = 1 };
        root.AddToGroup("enemy");
        root.AddChild(new AnimatedSprite2D
            { Name = "AnimatedSprite2D", Scale = Vector2.One });
        root.AddChild(new CollisionShape2D
            { Name = "CollisionShape2D", Shape = GuardCollision });
        var hurtbox = new Area2D
            { Name = "Hurtbox", CollisionLayer = 0, CollisionMask = 4 };
        hurtbox.AddChild(new CollisionShape2D
            { Name = "CollisionShape2D", Shape = GuardHurtbox });
        root.AddChild(hurtbox);
        var hitbox = new Area2D
            { Name = "Hitbox", CollisionLayer = 4, CollisionMask = 0 };
        hitbox.AddChild(new CollisionShape2D
            { Name = "CollisionShape2D", Shape = GuardHitbox });
        root.AddChild(hitbox);
        root = AttachScript(root,
            GD.Load<CSharpScript>("res://scripts/cs/EnemyGuard.cs"));
        PackAndSave(root, "res://scenes/enemy_guard.tscn");
    }

    static T AttachScript<T>(T node, Script s) where T : Node
    {
        var t = new Node();
        node.GetParentOrNull<Node>()?.RemoveChild(node);
        t.AddChild(node); node.SetScript(s);
        node = t.GetChild<T>(0); t.RemoveChild(node);
        return node;
    }

    void PackAndSave(Node root, string path)
    {
        SetOwnerRecursive(root, root);
        var packed = new PackedScene();
        if (packed.Pack(root) != Error.Ok)
            { GD.PushErr("[BuildEnemyGuard] Pack failed"); GetTree().Quit(1); return; }
        var test = packed.Instantiate();
        int n = CountNodes(test); test.Free();
        if (n < CountNodes(root))
            { GD.PushErr("[BuildEnemyGuard] Nodes dropped"); GetTree().Quit(1); return; }
        if (ResourceSaver.Save(packed, path) != Error.Ok)
            { GD.PushErr("[BuildEnemyGuard] Save failed"); GetTree().Quit(1); return; }
        GD.Print($"[BuildEnemyGuard] Saved {path} ({n} nodes)");
        GetTree().Quit(0);
    }

    void SetOwnerRecursive(Node node, Node owner)
    {
        foreach (Node c in node.GetChildren())
            if (string.IsNullOrEmpty(c.SceneFilePath))
            { c.Owner = owner; SetOwnerRecursive(c, owner); }
    }

    int CountNodes(Node node)
    {
        int c = 1;
        foreach (Node child in node.GetChildren()) c += CountNodes(child);
        return c;
    }
}
