package assetman;



enum Pattern
{
    Glob( pattern : String);
    ArrayGlob( patterns:Array<String> );
    RegEx( baseDirectory : String, pattern : String );
}
