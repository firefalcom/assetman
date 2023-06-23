package assetman;



enum Pattern
{
    Glob( pattern : String);
    RegEx( baseDirectory : String, pattern : String );
}