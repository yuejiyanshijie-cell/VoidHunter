using Godot;

namespace VoidHunter;

/// <summary>
/// Headless scene-tree builder: generates player.tscn
/// Run: godot --headless --script res://scripts/cs/builders/BuildPlayer.cs
/// </summary>
public partial class BuildPlayer : Node
{
    public override void _Ready() => Run();

    void Run()
    {
        GD.Print("[BuildPlayer] Building player.tscn ...");

        var root = new CharacterBody2D
        {
            Name = "Player",
            ZIndex = 10,
            CollisionLayer = 1,
            CollisionMask = 3
        };
        root.AddToGroup("player");

        // Collision
        var coll = new CollisionShape2D
        {
            Position = new Vector2(0, -2),
            Shape = new RectangleShape2D { Size = new Vector2(16, 28) }
        };
        root.AddChild(coll);

        // Hurtbox
        var hurtbox = new Area2D
        {
            Name = "Hurtbox",
            CollisionLayer = 0,
            CollisionMask = 2
        };
        hurtbox.AddChild(new CollisionShape2D
        {
            Shape = new CircleShape2D { Radius = 14f }
        });
        root.AddChild(hurtbox);

        // Hitbox
        var hitbox = new Area2D
        {
            Name = "Hitbox",
            Position = new Vector2(0, -2),
            CollisionLayer = 4,
            CollisionMask = 0
        };
        hitbox.AddChild(new CollisionShape2D
        {
            Position = new Vector2(12, 0),
            Shape = new RectangleShape2D { Size = new Vector2(40, 24) }
        });
        root.AddChild(hitbox);

        // Wall / Ground detectors
        root.AddChild(new RayCast2D
        {
            Name = "WallDetector",
            TargetPosition = new Vector2(20, 0)
        });
        root.AddChild(new RayCast2D
        {
            Name = "GroundDetector",
            TargetPosition = new Vector2(0, 8)
        });

        // AnimationPlayer (empty placeholder)
        root.AddChild(new AnimationPlayer());

        // Attach script via temp-parent pattern
        root = AttachScript(root, GD.Load<CSharpScript>("res://scripts/cs/Player.cs"));

        PackAndSave(root, "res://scenes/player.tscn");
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
            GD.PushError("[BuildPlayer] Pack failed: " + err);
            GetTree().Quit(1);
            return;
        }
        var test = packed.Instantiate();
        int got = CountNodes(test);
        test.Free();
        if (got < expected)
        {
            GD.PushError("[BuildPlayer] Nodes dropped: " + expected + " -> " + got);
            GetTree().Quit(1);
            return;
        }
        Error saveErr = ResourceSaver.Save(packed, path);
        if (saveErr != Error.Ok)
        {
            GD.PushError("[BuildPlayer] Save failed: " + saveErr);
            GetTree().Quit(1);
            return;
        }
        GD.Print("[BuildPlayer] Saved " + path + " (" + got + " nodes)");
        GetTree().Quit(0);
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
