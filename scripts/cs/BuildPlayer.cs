using Godot;

namespace VoidHunter;

/// <summary>
/// Headless scene builder: programmatically constructs the full Player scene
/// (.tscn) from the existing player.gd / player.tscn specification.
///
/// Run: godot --headless --script res://scripts/cs/BuildPlayer.cs
///
/// Generated scene node tree (10 nodes):
///   CharacterBody2D "Player"          groups=["player"]
///   ├─ AnimatedSprite2D
///   ├─ CollisionShape2D               (RectangleShape2D  16×28)
///   ├─ Hurtbox (Area2D)
///   │  └─ CollisionShape2D            (CircleShape2D     r=14)
///   ├─ Hitbox  (Area2D)
///   │  └─ CollisionShape2D            (RectangleShape2D  40×24)
///   ├─ WallDetector   (RayCast2D)     target=(20,0)
///   ├─ GroundDetector (RayCast2D)     target=(0,8)
///   └─ AnimationPlayer
/// </summary>
public partial class BuildPlayer : Node
{
    public override void _Ready() => Run();

    // ── Shared shape resources (reused across builds) ────────────
    static readonly RectangleShape2D PlayerCollisionShape = new()
    {
        Size = new Vector2(16, 28)
    };

    static readonly CircleShape2D PlayerHurtboxShape = new()
    {
        Radius = 14f
    };

    static readonly RectangleShape2D PlayerHitboxShape = new()
    {
        Size = new Vector2(40, 24)
    };

    // ── Entry point ──────────────────────────────────────────────
    void Run()
    {
        GD.Print("[BuildPlayer] Building player.tscn (comprehensive) ...");

        // ── Root: CharacterBody2D ────────────────────────────────
        var root = new CharacterBody2D
        {
            Name = "Player",
            ZIndex = 10,
            CollisionLayer = 1,
            CollisionMask = 3
        };
        root.AddToGroup("player");

        // ── AnimatedSprite2D ─────────────────────────────────────
        var sprite = new AnimatedSprite2D
        {
            Name = "AnimatedSprite2D",
            Position = new Vector2(0, -2),
            Scale = Vector2.One
        };
        root.AddChild(sprite);

        // ── CollisionShape2D ─────────────────────────────────────
        var collision = new CollisionShape2D
        {
            Name = "CollisionShape2D",
            Position = new Vector2(0, -2),
            Shape = PlayerCollisionShape
        };
        root.AddChild(collision);

        // ── Hurtbox (Area2D) ─────────────────────────────────────
        var hurtbox = new Area2D
        {
            Name = "Hurtbox",
            CollisionLayer = 0,
            CollisionMask = 2
        };
        hurtbox.AddChild(new CollisionShape2D
        {
            Name = "CollisionShape2D",
            Shape = PlayerHurtboxShape
        });
        root.AddChild(hurtbox);

        // ── Hitbox (Area2D) ──────────────────────────────────────
        var hitbox = new Area2D
        {
            Name = "Hitbox",
            Position = new Vector2(0, -2),
            CollisionLayer = 4,
            CollisionMask = 0
        };
        hitbox.AddChild(new CollisionShape2D
        {
            Name = "CollisionShape2D",
            Position = new Vector2(12, 0),
            Shape = PlayerHitboxShape
        });
        root.AddChild(hitbox);

        // ── WallDetector (RayCast2D) ─────────────────────────────
        var wallDetector = new RayCast2D
        {
            Name = "WallDetector",
            TargetPosition = new Vector2(20, 0)
        };
        root.AddChild(wallDetector);

        // ── GroundDetector (RayCast2D) ───────────────────────────
        var groundDetector = new RayCast2D
        {
            Name = "GroundDetector",
            TargetPosition = new Vector2(0, 8)
        };
        root.AddChild(groundDetector);

        // ── AnimationPlayer ──────────────────────────────────────
        var animPlayer = new AnimationPlayer
        {
            Name = "AnimationPlayer"
        };
        root.AddChild(animPlayer);

        // ── Attach script (temp-parent pattern) ─────────────────
        root = AttachScript(root,
            GD.Load<CSharpScript>("res://scripts/cs/Player.cs"));

        // ── Pack & save ─────────────────────────────────────────
        PackAndSave(root, "res://scenes/player.tscn");
    }

    // ===============================================================
    // Helper: attach a Script to a Node, preserving tree structure.
    // Godot requires removing a node from its parent before calling
    // SetScript. We temporarily reparent it under a dummy Node.
    // ===============================================================
    static T AttachScript<T>(T node, Script script) where T : Node
    {
        var temp = new Node();
        var parent = node.GetParentOrNull<Node>();
        if (parent != null)
            parent.RemoveChild(node);

        temp.AddChild(node);
        node.SetScript(script);
        node = temp.GetChild<T>(0);
        temp.RemoveChild(node);
        return node;
    }

    // ===============================================================
    // Pack the node tree into a PackedScene and save to disk.
    // Includes a round-trip sanity check against dropped nodes.
    // ===============================================================
    void PackAndSave(Node root, string path)
    {
        // Ownership is required for PackedScene.Pack to succeed.
        SetOwnerRecursive(root, root);

        int expectedCount = CountNodes(root);

        var packed = new PackedScene();
        Error packErr = packed.Pack(root);
        if (packErr != Error.Ok)
        {
            GD.PushError($"[BuildPlayer] Pack failed: {packErr}");
            GetTree().Quit(1);
            return;
        }

        // Round-trip: instantiate and verify node count.
        Node testInstance = packed.Instantiate();
        int actualCount = CountNodes(testInstance);
        testInstance.Free();

        if (actualCount < expectedCount)
        {
            GD.PushError(
                $"[BuildPlayer] Nodes dropped: expected {expectedCount}, got {actualCount}");
            GetTree().Quit(1);
            return;
        }

        Error saveErr = ResourceSaver.Save(packed, path);
        if (saveErr != Error.Ok)
        {
            GD.PushError($"[BuildPlayer] Save failed: {saveErr}");
            GetTree().Quit(1);
            return;
        }

        GD.Print($"[BuildPlayer] Saved {path} ({actualCount} nodes)");
        GetTree().Quit(0);
    }

    // ===============================================================
    // Walk the tree depth-first and assign .Owner = root on every
    // child so Godot packs them correctly.
    // ===============================================================
    void SetOwnerRecursive(Node node, Node root)
    {
        foreach (Node child in node.GetChildren())
        {
            if (string.IsNullOrEmpty(child.SceneFilePath))
            {
                child.Owner = root;
                SetOwnerRecursive(child, root);
            }
        }
    }

    // ===============================================================
    // Count total nodes in the tree for the sanity check.
    // ===============================================================
    int CountNodes(Node node)
    {
        int count = 1;
        foreach (Node child in node.GetChildren())
            count += CountNodes(child);
        return count;
    }
}
