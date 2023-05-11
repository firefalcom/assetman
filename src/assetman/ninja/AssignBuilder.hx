package assetman.ninja;

// Represent a Ninja variable assignation (it's more a binding, actually).
class AssignBuilder {
    var name : String;
    var value : String;

    public function new(name, value) {
        this.name = name;
        this.value = value;
    }

    // Write the assignation into a `stream`.
    public function write(stream: haxe.io.Output) {
        stream.writeString('${name} = ${value}\n');
    }
}