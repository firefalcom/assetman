package assetman;

// Helper class used in config script to assemble bundle edges
class BundleBuilder implements BuilderInterface {

    public var pattern : String;
    public var buildRelative : Bool;
    public var assignments : Map<String, String>;
    public var targets : Array<String>;
    public var rule : String;

    public function new(pattern) {
        this.pattern = pattern;
        this.buildRelative = false;
        this.assignments = new Map();
        this.targets = [];
    }

    public function fromBuild(fromBuild) {
        this.buildRelative = fromBuild;
        return this;
    }

    public function to(files) {
        targets = targets.concat(files);
        return this;
    }

    public function assign(key, value) {
        this.assignments[key] = value;
        return this;
    }

    public function usingRule(rule) {
        this.rule = rule;
    }
}