package assetman.ninja;

// Provide helpers to build a Ninja file by specifing high-level rules and
// targets.
class Builder {

    var edges : Array<EdgeBuilder>;
    var rules : Array<RuleBuilder>;
    var variables : Array<AssignBuilder>;
    var edgeCount : Int;
    var ruleCount : Int;
    var headerValue : String;
    var defaultRule : String;
    var version : String;
    var buildDir : String;

    // Create the builder, specifing an optional required Ninja `version`, and a
    // build directory (where Ninja put logs and where you can put
    // intermediary products).
    public function new(version = null, build_dir = null) {
        this.edges = [];
        this.rules = [];
        this.variables = [];
        this.edgeCount = 0;
        this.ruleCount = 0;
        this.version = version;
        this.buildDir = build_dir;
    }

    // Set an arbitrary header.
    public function header(value) {
        this.headerValue = value;
        return this;
    }

    // Specify the default rule by its `name`.
    public function byDefault(name) {
        this.defaultRule = name;
        return this;
    }

    // Add a variable assignation into `name` from the `value`.
    public function assign(name, value) {
        var clause = new AssignBuilder(name, value);
        this.variables.push(clause);
        return clause;
    }

    // Add a rule and return it.
    public function rule(name) {
        var clause = new RuleBuilder(name);
        this.rules.push(clause);
        this.ruleCount++;
        return clause;
    }

    // Add an edge and return it.
    public function edge(targets) {
        var clause = new EdgeBuilder(targets);
        this.edges.push(clause);
        this.edgeCount++;
        return clause;
    }

    // Write to a `stream`. It does not end the stream.
    public function saveToStream(stream : haxe.io.Output) {
        if(this.headerValue != null) { stream.writeString(this.headerValue + '\n\n'); }

        if(this.version != null) { stream.writeString('ninja_required_version = ${this.version}\n'); }

        if(this.buildDir != null) { stream.writeString('builddir=${this.buildDir}\n'); }

        for(clause in this.rules) {
            clause.write(stream);
        }

        for(clause in this.edges) {
            clause.write(stream);
        }

        for(clause in this.variables) {
            clause.write(stream);
        }

        if(this.defaultRule != null) { stream.writeString('default ${this.defaultRule}\n'); }
    }

    // Save the Ninja file on the filesystem at this `path` and call
    // `callback` when it's done.
    public function save(path) {
        var file = sys.io.File.write(path, false);
        this.saveToStream(file);
        file.close();
    }
}