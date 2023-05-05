package assetman.ninja;

class RuleBuilder {

    public var name : String;
    public var command : String;
    public var desc : String;
    public var dependencyFile : String;
    public var _pool : String;
    public var doRestat : Bool;
    public var isGenerator : Bool;

    public function new(name) {
        this.name  = name;
        command = '';
    }

    // Specify the command-line to run to execute the rule.
    public function run(command) {
        this.command = command;
        return this;
    }

    // Provide a description, displayed by Ninja instead of the bare command-
    // line.
    public function description(desc) {
        this.desc = desc;
        return this;
    }

    // Provide a Makefile-compatible dependency file for the rule products.
    public function depfile(file) {
        this.dependencyFile = file;
        return this;
    }

    public function restat(doRestat) {
        this.doRestat = doRestat;
        return this;
    }

    public function generator(isGenerator) {
        this.isGenerator = isGenerator;
        return this;
    }

    public function pool(pool) {
        this._pool = pool;
        return this;
    }

    // Write the rule into a `stream`.
    public function write(stream: haxe.io.Output) {
        stream.writeString('rule ${name}\n  command = ${command}\n');

        if(desc != null) { stream.writeString('  description = ${desc}\n'); }

        if(doRestat) { stream.writeString('  restat = 1\n'); }

        if(isGenerator) { stream.writeString('  generator = 1\n'); }

        if(_pool != null) { stream.writeString('  pool = ${_pool}\n'); }

        if(dependencyFile != null) {
            stream.writeString('  depfile = ${dependencyFile}\n');
            stream.writeString('  deps = gcc\n');
        }
    }
}
