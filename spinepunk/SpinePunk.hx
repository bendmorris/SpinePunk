package spinepunk;

import haxe.ds.ObjectMap;
import haxe.ds.Vector;
import flash.display.BitmapData;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import openfl.Assets;
import haxepunk.HXP;
import haxepunk.Camera;
import haxepunk.RenderMode;
import haxepunk.Entity;
import haxepunk.Graphic;
import haxepunk.graphics.Image;
import haxepunk.graphics.atlas.AtlasData;
import haxepunk.utils.MathUtil;
import spinehaxe.Bone;
import spinehaxe.Slot;
import spinehaxe.Skeleton;
import spinehaxe.SkeletonData;
import spinehaxe.SkeletonJson;
import spinehaxe.animation.AnimationState;
import spinehaxe.animation.AnimationStateData;
import spinehaxe.atlas.Atlas;
import spinehaxe.atlas.AtlasRegion;
import spinehaxe.attachments.Attachment;
import spinehaxe.attachments.RegionAttachment;
import spinehaxe.attachments.AtlasAttachmentLoader;
import spinehaxe.platform.openfl.BitmapDataTextureLoader;

using Lambda;

@:access(haxepunk.graphics.Image)
class SpinePunk extends Graphic
{
	static var atlasDataMap:Map<String, AtlasData> = new Map();
	static var p:Point = new Point();

	public var skeleton:Skeleton;
	public var skeletonData:SkeletonData;
	public var state:AnimationState;
	public var stateData:AnimationStateData;
	public var angle:Float = 0;
	public var speed:Float = 1;
	public var color:Int = 0xffffff;
	public var alpha:Float = 1;
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var scale:Float = 1;
	public var smooth = true;
	
	var name:String;
	var firstFrame = true;
	
	var cachedImages:ObjectMap<RegionAttachment, Image>;
	
	public function new(skeletonData:SkeletonData, smooth:Bool=true)
	{
		super();
		
		this.skeletonData = skeletonData;
		name = skeletonData.toString();
		
		if (stateData == null) stateData = new AnimationStateData(skeletonData);
		state = new AnimationState(stateData);
		
		skeleton = new Skeleton(skeletonData);
		skeleton.x = 0;
		skeleton.y = 0;
		skeleton.flipY = true;
		
		cachedImages = new ObjectMap();

		this.smooth = smooth;

		blit = HXP.renderMode != RenderMode.HARDWARE;
	}

	public var skin(default, set):String;
	function set_skin(skin:String)
	{
		if (skin != this.skin)
		{
			skeleton.skinName = skin;
			skeleton.setToSetupPose();
		}
		return this.skin = skin;
	}

	public var flipX(get, set):Bool;

	private function get_flipX():Bool
	{
		return skeleton.flipX;
	}

	private function set_flipX(value:Bool):Bool
	{
		if (value != skeleton.flipX)
		{
			skeleton.flipX = value;
			skeleton.updateWorldTransform();
		}

		return value;
	}

	public var flipY(get, set):Bool;

	private function get_flipY():Bool
	{
		return skeleton.flipY;
	}

	private function set_flipY(value:Bool):Bool
	{
		if (value != skeleton.flipY)
		{
			skeleton.flipY = value;
			skeleton.updateWorldTransform();
		}
			
		return value;
	}

	/**
	 * Get Spine animation data.
	 * @param	DataName	The name of the animation data files exported from Spine (.atlas .json .png).
	 * @param	DataPath	The directory these files are located at
	 * @param	Scale		Animation scale
	 */
	public static function readSkeletonData(dataName:String, dataPath:String, scale:Float = 1):SkeletonData
	{
		if (dataPath.lastIndexOf("/") < 0) dataPath += "/"; // append / at the end of the folder path
		var spineAtlas:Atlas = new Atlas(Assets.getText(dataPath + dataName + ".atlas"), new BitmapDataTextureLoader(dataPath));
		var json:SkeletonJson = new SkeletonJson(new AtlasAttachmentLoader(spineAtlas));
		json.scale = scale;
		var skeletonData:SkeletonData = json.readSkeletonData(Assets.getText(dataPath + dataName + ".json"), dataName);
		return skeletonData;
	}

	public override function update():Void
	{
		state.update(HXP.elapsed*speed);
		state.apply(skeleton);
		skeleton.updateWorldTransform();
		
		super.update();
	}

	public override function renderAtlas(layer:Int, point:Point, camera:Camera):Void
	{
		draw(point, camera, layer);
	}

	public override function render(target:BitmapData, point:Point, camera:Camera):Void
	{
		draw(point, camera, 0, target);
	}

	function draw(point:Point, camera:Camera, layer:Int=0, target:BitmapData=null):Void
	{
		p.x = point.x; p.y = point.y;
		var point = p;
		var drawOrder:Array<Slot> = skeleton.drawOrder;
		var flipX:Int = (skeleton.flipX) ? -1 : 1;
		var flipY:Int = (skeleton.flipY) ? 1 : -1;
		var flip:Int = flipX * flipY;
		
		var radians:Float = angle * MathUtil.RAD;
		var cos:Float = Math.cos(radians);
		var sin:Float = Math.sin(radians);
		
		var sx = scaleX * scale;
		var sy = scaleY * scale;
		
		var attachment:Attachment;
		var regionAttachment:RegionAttachment;
		var wrapper:Image;
		var region:AtlasRegion;
		var bone:Bone;
		var dx:Float, dy:Float;
		var relX:Float, relY:Float;
		var rx:Float, ry:Float;
		
		for (slot in drawOrder)
		{
			attachment = slot.attachment;
			if (Std.is(attachment, RegionAttachment))
			{
				regionAttachment = cast attachment;
				wrapper = getImage(regionAttachment);
				wrapper.color = color;
				wrapper.alpha = alpha;

				region = cast regionAttachment.rendererObject;
				bone = slot.bone;
				rx = regionAttachment.x;// + region.offsetX;
				ry = regionAttachment.y;// + region.offsetY;

				var m = HXP.matrix;
				m.identity();
				m.scale(wrapper.scaleX, wrapper.scaleY);
				m.rotate(-wrapper.angle * MathUtil.RAD);
				m.translate(wrapper.originX, wrapper.originY);
				m.scale(bone.worldScaleX * flipX * sx, bone.worldScaleY * flipY * sy);
				m.rotate(flip * bone.worldRotation * MathUtil.RAD);
				m.translate(
					skeleton.x + bone.worldX + point.x + wrapper.x - camera.x * scrollX,
					skeleton.y + bone.worldY + point.y + wrapper.y - camera.y * scrollY
				);
				m.scale(camera.fullScaleX, camera.fullScaleY);

				if (blit) wrapperRender(wrapper, m, target, point, camera);
				else wrapperRenderAtlas(wrapper, m, layer, point, camera);
			}
		}
	}

	public function getImage(regionAttachment:RegionAttachment):Image
	{
		if (cachedImages.exists(regionAttachment))
			return cachedImages.get(regionAttachment);
		
		var region:AtlasRegion = cast regionAttachment.rendererObject;
		var texture:BitmapData = cast region.page.rendererObject;
		
		var atlasData = atlasDataMap[name];
		if (atlasData == null)
		{
			var cachedGraphic:BitmapData = texture;
			atlasData = new AtlasData(cachedGraphic);
			atlasDataMap[name] = atlasData;
		}
		
		var rect = HXP.rect;
		rect.x = region.x;
		rect.y = region.y;
		rect.width = region.width;
		rect.height = region.height;
		
		var wrapper:Image;
		
		if (blit)
		{
			var bd = new BitmapData(cast rect.width, cast rect.height, true, 0);
			HXP.point.x = HXP.point.y = 0;
			bd.copyPixels(texture, rect, HXP.point);
			wrapper = new Image(bd);
		} else
		{
			wrapper = new Image(atlasData.createRegion(rect));
		}

		var regionWidth:Float = region.rotate ? region.height : region.width;
		var regionHeight:Float = region.rotate ? region.width : region.height;

		wrapper.angle = -regionAttachment.rotation;
		wrapper.smooth = smooth;
		wrapper.scaleX = regionAttachment.scaleX * (regionAttachment.width / region.width);
		wrapper.scaleY = regionAttachment.scaleY * (regionAttachment.height / region.height);

		var rad:Float = regionAttachment.rotation * MathUtil.RAD,
			cos:Float = Math.cos(rad),
			sin:Float = Math.sin(rad);
		var shiftX:Float = -regionAttachment.width / 2 * regionAttachment.scaleX;
		var shiftY:Float = -regionAttachment.height / 2 * regionAttachment.scaleY;

		if (region.rotate)
		{
			wrapper.angle += 90;
			shiftX += regionHeight * (regionAttachment.width / region.width);
		}

		wrapper.originX = regionAttachment.x + shiftX * cos - shiftY * sin;
		wrapper.originY = -regionAttachment.y + shiftX * sin + shiftY * cos;

		cachedImages.set(regionAttachment, wrapper);

		return wrapper;
	}

	inline function wrapperRender(wrapper:Image, m:Matrix, target:BitmapData, point:Point, camera:Camera)
	{
		target.draw(wrapper._bitmap, m, null, wrapper.blend, null, wrapper._bitmap.smoothing);
	}

	inline function wrapperRenderAtlas(wrapper:Image, m:Matrix, layer:Int, point:Point, camera:Camera)
	{
		wrapper._region.drawMatrix(m.tx, m.ty, m.a, m.b, m.c, m.d, layer, wrapper._red, wrapper._green, wrapper._blue, wrapper._alpha, wrapper.smooth);
	}
}
