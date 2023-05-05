package assetman;


class RuleBuilder {

    public var _name : String;
    public var _command : String;

    public function new(name) {
        _name = name;
    }

    public function command(command){
        _command = command;
    }

}
