package assetman.ninja;


class EdgeBuilder {
    // Construct an edge specifing the resulting files, as `targets`, of the
    // edge.

    var assigns : Map<String, String>;
    var targets : Array<String>;
    var sources : Array<String>;
    var dependencies : Array<String>;
    var orderDeps : Array<String>;
    var rule : String;
    var _pool : String;

    public function new(targets) {
        assigns = [];
        rule = 'phony';
        //if typeof @targets == 'string'
        this.targets = targets;
    }

    // Define the Ninja `rule` name to use to build this edge.
    public function usingRule(rule) {
        this.rule = rule;
        return this;
    }

    // Define one or several direct `sources`, that is, files to be transformed
    // by the rule.
    public function from(sources : Dynamic) {
        var _sources : Array<String> = sources;

        if(Std.isOfType(sources, String)) {
            _sources = [(sources:String)];
        }

        if(this.sources != null) {
            this.sources = this.sources.concat(_sources);
        } else {
            this.sources = _sources;
        }

        return this;
    }

    // Define one or several indirect `dependencies`, that is, files needed but
    // not part of the compilation or transformation.
    public function need(dependencies) {
        throw "need(dependencies)";
        /*if typeof dependencies == 'string'
        dependencies = [dependencies]
        unless @dependencies?
        @dependencies = dependencies
        else
            @dependencies = @dependencies.concat dependencies
        */
        return this;
    }

    // Define one or several order-only dependencies in `orderDeps`, that is,
    // this edge should be build after those dependencies are.
    public function after(orderDeps) {
        throw "if typeof orderDeps == 'string'";/*
            orderDeps = [orderDeps]
        unless @orderDeps?
            @orderDeps = orderDeps
        else
            @orderDeps = @orderDeps.concat orderDeps
        */
        return this;
    }

    // Bind a variable to a temporary value for the edge.
    public function assign(name : String, value : String) {
        assigns[name] = value;
        return this;
    }

    // Assign this edge to a pool.
    // See https://ninja-build.org/manual.html#ref_pool
    public function pool(pool) {
        this._pool = pool;
        return this;
    }

    // Write the edge into a `stream`.
    public function write(stream: haxe.io.Output) {
        stream.writeString('build ${targets.join(' ')}: ${rule}');

        if(sources != null) { stream.writeString(' ' + sources.join(' ')); }

        if(dependencies != null) {
            stream.writeString(' | ' + dependencies.join(' '));
        }

        if(orderDeps != null) {
            stream.writeString(' || ' + orderDeps.join(' '));
        }

        for(name => value in assigns) {
            stream.writeString('\n  ${name} = ${value}');
        }

        stream.writeString('\n');

        if(_pool != null) {
            stream.writeString('  pool = ${_pool}\n');
        }
    }
}