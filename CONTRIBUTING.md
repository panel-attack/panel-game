# Contributing Code

The best place to coordinate contributions is through the issue tracker and the [official Discord server](http://discord.panelattack.com).

If you have an idea, please reach out in the #pa-development channel of the discord or on github to make sure others agree and coordinate.  

Try to follow the following code guidelines when contributing:
- Separate functionality into separate files that only interact with each other as much as needed
- Avoid globals
- Make smaller methods
- Don’t duplicate code, break it into smaller reusable chunks and use that in both spots
- Writing tests for how the code should work is extremely beneficial
- Follow the formatting guidelines below
- Constants should be local to a file / scope unless they need to be shared everywhere
- Avoid the use of shortlived tables and consider pooling if you can't
- Avoid use of luajit's ffi module; jit is disabled on our weakest platform, making ffi extremely slow

Pull requests are to be pulled against the `beta` branch.  

## Formatting Guidelines

- Constants should be `ALL_CAPS_WITH_UNDERSCORES_BETWEEN_WORDS`
- Class names start with a capital like `BattleRoom`
- All other names use `camelCase`
- You should set your editor to use 2 spaces of identation. (not tabs)
- Avoid lines longer than 140 characters
- All control flow like if and functions should be on multiple lines, not condensed into a single line. Putting it all on a single line can make it harder to follow the flow.

For those using VSCode we recommend using this [styling extension](https://marketplace.visualstudio.com/items?itemName=Koihik.vscode-lua-format) with the configuration file in the repository named VsCodeStyleConfig.lua-format

# Contributing Assets

## Legal concerns and licensing

There is no formal organization behind Panel Attack and there is none who possesses Panel Attack, it is the collective work of many individual contributors. This has legal implications when it comes to using assets in Panel Attack:  
We aren't lawyers but to our current understanding there are potential problems with the project not being able to act as a juridical person for the purpose of holding or buying copyright of assets or even being legally competent to sign any contracts.

Additionally Panel Attack is a project in the spirit of free open source software and no asset added to the project should make future users and contributors liable to consequences from using assets with unclear license status.  

Thus, in order to protect the project and its contributors, all new assets must be licensed under the [CC BY-NC-SA](https://creativecommons.org/licenses/by-nc-sa/4.0/) or a more permissive license of irrevocable nature. We do not accept CC licenses using the ND (no derivatives) clause as we feel this restriction to be too limiting for the nature of the project.

## Technicalities

Please ensure the following requirements are met for submitting pull requests containing assets:
- All assets are mentioned by file path and name in the repository's license file with the correct license and copyright holder
- All assets additionally have the license and copyright notice stored in their metadata
  - If the copyright holder provided a link to their web presence, it has to be included in the metadata as well
  - For music only:
    - Music should additionally include a title and artist in the respective metadata fields
    - If music was created specifically for use in Panel Attack it would be appreciated if the metadata also contained a link to the Panel Attack website

Project files with the purpose to facilitate the creation of future derivatives are to be submitted to the [panel-attack/panel-attack-resources](https://github.com/panel-attack/panel-attack-resources) repository.

### How to include metadata

This can prove to be a bit finnicky so this section should provide a bit of guidance on how to include metadata.  
This is no legal advice.  
Please note that the CC project recommends creators using CC licenses to provide verification info on their own webpage which goes beyond the recommendations here, see [here](https://wiki.creativecommons.org/wiki/Web_Statement) for more information.

#### Images

There is an entire jungle of possible metadata for images, depending on their format, what they were created with etc.  
To guarantee that the metadata is visible in common software, it is recommended to use the ISO standard [XMP](https://en.wikipedia.org/wiki/Extensible_Metadata_Platform).  

##### Minimal metadata

To do these contribution guidelines justice, images should include in their XMP metadata the tags at the minimum
- `dc:Creator` to indicate the creator
- `dc:Rights` to indicate the copyright of the creator, year of creation and the license the artwork is available under

##### Creative Commons metadata

In case of a CC license, additionally the minimum of these fields should be set:
- `cc:License` should contain only a link to the relevant CC license
- `cc:AttributionName` should contain the name the creator wishes their work to be attributed with

##### Including a web presence

For including a link to the author web presence, using the `dc:Description` field seems most suitable.

##### Example using exiftool

Using exiftool you may apply metadata in this way:
```
exiftool -XMP-dc:Creator="AuthorName" -XMP-cc:AttributionName="AuthorName" -XMP-cc:License="https://creativecommons.org/licenses/by-sa/4.0/"  -XMP-dc:Rights="Copyright, AuthorName, Year. This work is licensed under the Creative Commons Attribution ShareAlike 4.0 International License. To view a copy of this license, visit https://creativecommons.org/licenses/by-sa/4.0/"  image.png
```

In case of small files it would be appreciated if metadata added by image editors would be stripped which can be done by setting `xmp-group:all` to nothing such as `-EXIF= -XMP-xmp:all= -XMP-exif:all= -XMP-tiff:all= `.

##### Inspecting XMP metadata

Besides exiftool you can of course use other editors and most image editing and painting tools come with that functionality to some degree.  
XMP metadata in images is human readable and typically located at the start of a file so you may also inspect them by opening an image in a text editor.  
It may look as such:

```XML
<x:xmpmeta xmlns:x='adobe:ns:meta/' x:xmptk='Image::ExifTool 13.02'>
<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>

 <rdf:Description rdf:about=''
  xmlns:cc='http://creativecommons.org/ns#'>
  <cc:attributionName>JamBox</cc:attributionName>
  <cc:license rdf:resource='https://creativecommons.org/licenses/by-sa/4.0/'/>
 </rdf:Description>

 <rdf:Description rdf:about=''
  xmlns:dc='http://purl.org/dc/elements/1.1/'>
  <dc:creator>
   <rdf:Seq>
    <rdf:li>JamBox</rdf:li>
   </rdf:Seq>
  </dc:creator>
  <dc:rights>
   <rdf:Alt>
    <rdf:li xml:lang='x-default'>Copyright, JamBox, 2024. This work is licensed under the Creative Commons Attribution ShareAlike 4.0 International License. To view a copy of this license, visit https://creativecommons.org/licenses/by-sa/4.0/</rdf:li>
   </rdf:Alt>
  </dc:rights>
 </rdf:Description>
</rdf:RDF>
</x:xmpmeta>
```


#### Audio

Most audio files will use the ogg container which supports the inclusion of the metadata fields.  
Please aways use:
- `COPYRIGHT` to indicate your copyright
- `LICENSE` to indicate the CC License

and in the case of music also
- `ARTIST` and `TITLE` 

For additional information:
- `CONTACT` for contact information, usually a website or email address
- `COMMENT` to include further information

Please refer to the [official metadata documentation](https://www.xiph.org/vorbis/doc/v-comment.html) of ogg for more information.

## Coordination

Cohesiveness is a difficult task in a community of voluntary contributors but a much desired quality in a video game.

Please use the [Discord server](http://discord.panelattack.com) to coordinate with others in the #pacci channel in advance if you wish to contribute.  
