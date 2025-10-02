TVMissile Plugin (巡飞弹插件)
🌟 插件简介 / Introduction

中文：
TV巡飞弹插件允许玩家发射一枚火箭导弹，并通过自己的视角来控制导弹的飞行方向。
插件支持多种自定义效果：导弹飞行速度、转向灵敏度、爆炸伤害、飞行/爆炸音效、以及飞行视角叠加层（类似“电视制导导弹”效果）。

English:
The TVMissile plugin allows players to fire a rocket missile and control its flight path using their own view.
It supports customizable features such as flight speed, turn sensitivity, explosion damage, flight/explosion sounds, and view overlays (for a TV-guided missile effect).

⚙️ 控制变量 (CVARs)
CVAR 名称	默认值	说明 (中文)	Description (English)
tv_interval	0.02	导弹飞行更新间隔（秒）	Update interval of missile flight (seconds)
tv_speed	400.0	导弹飞行速度	Missile flight speed
tv_turnfactor	0.2	导弹转向灵敏度	Missile turning sensitivity
tv_damage	100.0	导弹爆炸伤害	Missile explosion damage
tv_flysound	1	是否播放飞行音效 (0=否, 1=是)	Enable missile flying sound (0=No, 1=Yes)
tv_expsound	1	是否播放爆炸音效 (0=否, 1=是)	Enable explosion sound (0=No, 1=Yes)
tv_flyoverlay	1	是否显示飞行叠加层	Enable missile flight overlay
tv_endoverlay	1	是否显示结束叠加层	Enable overlay when missile ends
📂 配置文件 (Config File)

配置文件示例：
addons/sourcemod/configs/tvmissile.cfg

// TV Missile 配置文件
// tvweapon 支持多个武器用 , 隔开(例如  weapon_scout,weapon_xunfeidan,weapon_m4a1 )
// flysound 巡飞弹飞行音效 多个声路径用 , 隔开
// expsound 巡飞弹爆炸音效 多个声路径用 , 隔开
// firesound 巡飞弹发射音效 多个声路径用 , 隔开
// oversound 巡飞弹结束花屏音效 多个声路径用 , 隔开
// overlayzoom 巡飞弹飞行显示的准星叠加层 路径
// overoverlay 巡飞弹结束花屏叠加层 路径

"TVMissile"
{
    "tvweapon"      "weapon_scout,weapon_xunfeidan"
    "flysound"      "weapons/rpg/rocket1.wav"
    "expsound"      "weapons/huazai/herosvd/explode3.wav,weapons/huazai/herosvd/explode4.wav,weapons/huazai/herosvd/explode5.wav"
    "firesound"     "weapons/huazai/herosvd/svdex-launcher.wav"
    "oversound"     "xuehua/xuehua.mp3"
    "overlayzoom"   "overlays/xunfeidan/xunfei"
    "overoverlay"   "overlays/xunfeidan/xuehua1"
}

🎮 使用说明 / Usage

给玩家配置好的武器（如 weapon_scout 或自定义 weapon_xunfeidan），玩家发射时会生成一枚可控导弹。
如果启用了 overlay，则导弹飞行时玩家会看到一个 HUD/准星叠加层，增强 TV 导弹的感觉。

Players with the configured weapons (e.g., weapon_scout or custom weapon_xunfeidan) can fire controllable missiles.
If overlays are enabled, a HUD crosshair overlay will appear during flight, giving the feeling of a TV-guided missile.
