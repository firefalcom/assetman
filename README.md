assetman
========

Haxe library used to generate ninja file.

The goal is to scan the directories, and using the rules, generate a ninja.build

Rules
-----

You can create rules, that will be reused later

        rule('convert2').command("cp $in $out");
        rule('convert').command("cp $in $out");
        rule('atlas').command("cat $in > $name");

`$in` and `$out` are default from ninja, but here, `$name` is a variable that will be set later when rule is used

Patterns
--------

Pattern are use to apply rule to file sets

        var pattern = '**/*.png';
        // build foo@2x.png: convert2 ../src/foo.psd
        single(pattern).to("$filename@2x.png").usingRule('convert2');
        // build foo.png: convert ../src/foo.psd
        single(pattern).toExt('.png').usingRule('convert');
        var atlasName = 'atlas';
        // build atlas.png atlas.csv: atlas foo.png foo@2x.png
        //     name = atlas
        bundle('images/*.png')
            .fromBuild(true)
            .to([atlasName + '.png', atlasName + '.csv'])
            .assign('name', atlasName)
            .usingRule('atlas');


Acknowledgment
--------------

This library was heavily inspired by https://github.com/tylorr/assetman