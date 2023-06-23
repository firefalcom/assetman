package assetman;


interface BuilderInterface {
    var buildRelative : Bool;
    var pattern : Pattern;
    var excludes : Array<Pattern>;
}