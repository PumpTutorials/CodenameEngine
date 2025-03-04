package funkin.system;

import funkin.away3d.Flx3DView;
import openfl.utils.AssetLibrary;
import openfl.utils.AssetCache;
import openfl.text.TextFormat;
import flixel.system.ui.FlxSoundTray;
import funkin.windows.WindowsAPI;
import funkin.menus.TitleState;
import funkin.game.Highscore;
import funkin.options.Options;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.TransitionData;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
#if desktop
import funkin.system.Discord.DiscordClient;
import sys.thread.Thread;
#end
import lime.app.Application;

#if sys
import sys.io.File;
#end
// TODO: REMOVE TEST
import funkin.mods.ModsFolder;

class Main extends Sprite
{
	// TODO: CREDIT SMOKEY FOR ATLAS STUFF!!
	
	var gameWidth:Int = 1280; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = TitleState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 120; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets

	// You can pretty much ignore everything from here on - your code should go in your states.

	#if sys
	public static var gameThreads:Array<Thread> = [];
	#end

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		if (stage != null)
		{
			init();
		}
		else
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void
	{
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}

		#if !debug
		initialState = TitleState;
		#end


		addChild(new FlxGame(gameWidth, gameHeight, null, zoom, framerate, framerate, skipSplash, startFullscreen));
		loadGameSettings();
		FlxG.switchState(new TitleState());
		
		#if !mobile
		addChild(new FramerateField(10, 3, 0xFFFFFF));
		#end
	}

	@:dox(hide)
	public static var audioDisconnected:Bool = false;
	
	public static var changeID:Int = 0;

	
	private static var __threadCycle:Int = 0;
	public static function execAsync(func:Void->Void) {
		#if sys
		var thread = gameThreads[(__threadCycle++) % gameThreads.length];
		thread.events.run(func);
		#else
		func();
		#end
	}

	public function loadGameSettings() {
		#if sys
		for(i in 0...4)
			gameThreads.push(Thread.createWithEventLoop(function() {Thread.current().events.promise();}));
		#end
		Paths.assetsTree = new AssetsLibraryList();

		CrashHandler.init();
		Logs.init();
		Paths.init();
		ModsFolder.init();
		Flx3DView.init();
		#if MOD_SUPPORT
		ModsFolder.switchMod("introMod");
		#end
		
		#if GLOBAL_SCRIPT
		funkin.scripting.GlobalScript.init();
		#end
		
		#if sys
		if (Sys.args().contains("-livereload")) {
			#if USE_SOURCE_ASSETS
			trace("Used lime test windows. Switching into source assets.");
			Paths.assetsTree.addLibrary(ModsFolder.loadLibraryFromFolder('assets', './../../../../assets/', true));
			#else
			Assets.registerLibrary('assets', Paths.assetsTree.base);
			#end

			var buildNum:Int = Std.parseInt(File.getContent("./../../../../buildnumber.txt"));
			buildNum++;
			File.saveContent("./../../../../buildnumber.txt", Std.string(buildNum));
		} else {
			#if USE_ADAPTED_ASSETS
			Paths.assetsTree.addLibrary(ModsFolder.loadLibraryFromFolder('assets', './assets/', true));
			#else
			Assets.registerLibrary('assets', Paths.assetsTree.base);
			#end
		}
		#else
		Assets.registerLibrary('assets', Paths.assetsTree.base);
		#end


		var lib = new AssetLibrary();
		@:privateAccess
		lib.__proxy = Paths.assetsTree;
		Assets.registerLibrary('default', lib);

		funkin.options.PlayerSettings.init();
		FlxG.save.bind('Save');
		Options.load();
		Highscore.load();

		FlxG.fixedTimestep = false;

		refreshAssets();

		Conductor.init();
		AudioSwitchFix.init();
		WindowsAPI.setDarkMode(true);

		
		#if desktop
		DiscordClient.initialize();
		
		Application.current.onExit.add (function (exitCode) {
			DiscordClient.shutdown();
		 });
		#end
		
		FlxG.signals.preStateCreate.add(onStateSwitch);

		initTransition();
	}

	public static function refreshAssets() {
		FlxSoundTray.volumeChangeSFX = Paths.sound('menu/volume');

		if (FlxG.game.soundTray != null)
			FlxG.game.soundTray.text.setTextFormat(new TextFormat(Paths.font("vcr.ttf")));
	}

	public static function initTransition() {
		var diamond:FlxGraphic = FlxGraphic.fromClass(GraphicTransTileDiamond);
		diamond.persist = true;
		diamond.destroyOnNoUse = false;

		FlxTransitionableState.defaultTransIn = new TransitionData(FADE, 0xFF000000, 1, new FlxPoint(0, -1), {asset: diamond, width: 32, height: 32},
			new FlxRect(-200, -200, FlxG.width * 1.4, FlxG.height * 1.4));
		FlxTransitionableState.defaultTransOut = new TransitionData(FADE, 0xFF000000, 0.7, new FlxPoint(0, 1),
			{asset: diamond, width: 32, height: 32}, new FlxRect(-200, -200, FlxG.width * 1.4, FlxG.height * 1.4));
	}

    private static function onStateSwitch(newState:FlxState) {
        // manual asset clearing since base openfl one doesnt clear lime one
        // doesnt clear bitmaps since flixel fork does it auto
        
        var cache = cast(Assets.cache, AssetCache);
        for (key=>font in cache.font)
            cache.removeFont(key);
        for (key=>sound in cache.sound)
            cache.removeSound(key);

		Paths.assetsTree.clearCache();


    }
}
