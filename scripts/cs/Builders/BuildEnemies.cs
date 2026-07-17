using Godot;

namespace VoidHunter;

/// <summary>
/// Headless scene-tree builder: generates enemy_boss.tscn, enemy_guard.tscn, enemy_bug.tscn
/// Run: godot --headless --script res://scripts/cs/builders/BuildEnemies.cs
/// </summary>
public partial class BuildEnemies : Node
{
    public override void _Ready() => Run();

    void Run()
    {
        GD.Print("[BuildEnemies] Building enemy scenes ...");

        BuildEnemyBoss();
        BuildEnemyGuard();
        BuildEnemyBug();

        GD.Print("[BuildEnemies] All enemies built.");
        GetTree().Quit(0);
    }

    // ── Enemy Boss ──
    void BuildEnemyBoss()
    {
        var root = new CharacterBody2D
        {
            Name = "EnemyBoss",
            CollisionLayer = 2,
            CollisionMask = 1
        };
        root.AddToGroup("enemy");

        root.AddChild(new CollisionShape2D
        {
            Shape = new RectangleShape2D { Size = new Vector2(40, 30) }
        });

        root = AttachScript(root, GD.Load<CSharpScript>("res://scripts/cs/EnemyBoss.cs"));
        PackAndSave(root, "res://scenes/enemy_boss.tscn");
    }

    // ── Enemy Guard ──
    void BuildEnemyGuard()
    {
        var root = new CharacterBody2D
        {
            Name = "EnemyGuard",
            CollisionLayer = 2,
            CollisionMask = 1
        };
        root.AddToGroup("enemy");

        root.AddChild(new CollisionShape2D
        {
            Shape = new RectangleShape2D { Size = new Vector2(22, 22) }
        });

        root = AttachScript(root, GD.Load<CSharpScript>("res://scripts/cs/EnemyGuard.cs"));
        PackAndSave(root, "res://scenes/enemy_guard.tscn");
    }

    // ── Enemy Bug ──
    void BuildEnemyBug()
    {
        var root = new CharacterBody2D
        {
            Name = "EnemyBug",
            CollisionLayer = 2,
            CollisionMask = 1
        };
        root.AddToGroup("enemy");

        root.AddChild(new CollisionShape2D
        {
            Shape = new RectangleShape2D { Size = new Vector2(20, 10) }
        });

        root = AttachScript(root, GD.Load<CSharpScript>("res://scripts/cs/EnemyBug.cs"));
        PackAndSave(root, "res://scenes/enemy_bug.tscn");
    }

    // ===================================================================
    // godogen-style helpers
    // ===================================================================

    static T AttachScript<T>(T node, Script script) where T : Node
    {
        var temp = new Node();
        var parent = node.GetParentOrNull<Node>();
        if (parent != null) parent.RemoveChild(node);
        temp.AddChild(node);
        node.SetScript(script);
        node = temp.GetChild<T>(0);
        temp.RemoveChild(node);
        return node;
    }

    void PackAndSave(Node root, string path)
    {
        SetOwnerRecursive(root, root);

        int expected = CountNodes(root);
        var packed = new PackedScene();
        Error err = packed.Pack(root);
        if (err != Error.Ok)
        {
            GD.PushError("[BuildEnemies] Pack failed (" + path + "): " + err);
            GetTree().Quit(1);
            return;
        }
        var test = packed.Instantiate();
        int got = CountNodes(test);
        test.Free();
        if (got < expected)
        {
            GD.PushError("[BuildEnemies] Nodes dropped (" + path + "): " + expected + " -> " + got);
            GetTree().Quit(1);
            return;
        }
        Error saveErr = ResourceSaver.Save(packed, path);
        if (saveErr != Error.Ok)
        {
            GD.PushError("[BuildEnemies] Save failed (" + path + "): " + saveErr);
            GetTree().Quit(1);
            return;
        }
        GD.Print("[BuildEnemies] Saved " + path + " (" + got + " nodes)");
    }

    void SetOwnerRecursive(Node node, Node root)
    {
        foreach (var child in node.GetChildren())
        {
            if (child is Node n && string.IsNullOrEmpty(n.SceneFilePath))
            {
                n.Owner = root;
                SetOwnerRecursive(n, root);
            }
        }
    }

    int CountNodes(Node node)
    {
        int n = 1;
        foreach (var child in node.GetChildren())
            n += CountNodes(child);
        return n;
    }
}
