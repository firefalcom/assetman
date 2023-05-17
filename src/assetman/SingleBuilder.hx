package assetman;

class SingleBuilder implements BuilderInterface {
    public var pattern : String;
    public var target : String;
    public var buildRelative : Bool;
    public var assignments : Map<String, String>;
    public var rule : String;

    public function new(pattern) {
      this.pattern = pattern;
      this.buildRelative = false;
      this.assignments = new Map();
    }

    public function fromBuild( build_relative ) {
      this.buildRelative = build_relative;
      return this;
    }

    public function to(target) {
      this.target = target;
      return this;
    }

    public function toExt(ext) {
      this.target = '$$filename' + ext;
      return this;
    }

    public function assign(key, value) {
      this.assignments[key] = value;
      return this;
    }

    public function usingRule(rule) {
      this.rule = rule;
      return this;
    }
}