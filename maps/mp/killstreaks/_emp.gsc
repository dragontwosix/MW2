#include maps\mp\_utility;
#include common_scripts\utility;


init()
{
	level._effect[ "emp_flash" ] = loadfx( "explosions/emp_flash_mp" );

	level.teamEMPed["allies"] = false;
	level.teamEMPed["axis"] = false;
	level.empPlayer = undefined;
	
	if ( level.teamBased )
		level thread EMP_TeamTracker();
	else
		level thread EMP_PlayerTracker();
	
	level.killstreakFuncs["emp"] = ::EMP_Use;
	
	level thread onPlayerConnect();
	
}



onPlayerConnect()
{
	for(;;)
	{
		level waittill("connected", player);
		player thread onPlayerSpawned();
	}
}


onPlayerSpawned()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill( "spawned_player" );
		
		if ( (level.teamBased && level.teamEMPed[self.team]) || (!level.teamBased && isDefined( level.empPlayer ) && level.empPlayer != self) )
			self setEMPJammed( true );
	}
}


EMP_Use( lifeId, delay )
{
	assert( isDefined( self ) );

	if ( !isDefined( delay ) )
		delay = 5.0;

	myTeam = self.pers["team"];
	otherTeam = level.otherTeam[myTeam];

	self thread AttackLittlebird( lifeId );

	self maps\mp\_matchdata::logKillstreakEvent( "emp", self.origin );
	self notify( "used_emp" );

	return true;
}


EMP_JamTeam( teamName, duration, delay )
{
	level endon ( "game_ended" );
	
	assert( teamName == "allies" || teamName == "axis" );

	//wait ( delay );

	thread teamPlayerCardSplash( "used_emp", self );

	level notify ( "EMP_JamTeam" + teamName );
	level endon ( "EMP_JamTeam" + teamName );
	
	foreach ( player in level.players )
	{
		player playLocalSound( "emp_activate" );
		
		if ( player.team != teamName )
			continue;
		
		if ( player _hasPerk( "specialty_localjammer" ) )
			player RadarJamOff();
	}
	
	visionSetNaked( "coup_sunblind", 0.1 );
	thread empEffects();
	
	wait ( 0.1 );
	
	// resetting the vision set to the same thing won't normally have an effect.
	// however, if the client receives the previous visionset change in the same packet as this one,
	// this will force them to lerp from the bright one to the normal one.
	visionSetNaked( "coup_sunblind", 0 );
	visionSetNaked( getDvar( "mapname" ), 3.0 );
	
	level.teamEMPed[teamName] = true;
	level notify ( "emp_update" );
	
	level destroyActiveVehicles( self );
	
	maps\mp\gametypes\_hostmigration::waitLongDurationWithHostMigrationPause( duration );
	
	level.teamEMPed[teamName] = false;
	
	foreach ( player in level.players )
	{
		if ( player.team != teamName )
			continue;
		
		if ( player _hasPerk( "specialty_localjammer" ) )
			player RadarJamOn();
	}
	
	level notify ( "emp_update" );
}

EMP_JamPlayers( owner, duration, delay )
{
	level notify ( "EMP_JamPlayers" );
	level endon ( "EMP_JamPlayers" );
	
	assert( isDefined( owner ) );
	
	//wait ( delay );
	
	foreach ( player in level.players )
	{
		player playLocalSound( "emp_activate" );
		
		if ( player == owner )
			continue;
		
		if ( player _hasPerk( "specialty_localjammer" ) )
			player RadarJamOff();
	}
	
	visionSetNaked( "coup_sunblind", 0.1 );
	thread empEffects();

	wait ( 0.1 );
	
	// resetting the vision set to the same thing won't normally have an effect.
	// however, if the client receives the previous visionset change in the same packet as this one,
	// this will force them to lerp from the bright one to the normal one.
	visionSetNaked( "coup_sunblind", 0 );
	visionSetNaked( getDvar( "mapname" ), 3.0 );
	
	level notify ( "emp_update" );
	
	level.empPlayer = owner;
	level.empPlayer thread empPlayerFFADisconnect();
	level destroyActiveVehicles( owner );
	
	level notify ( "emp_update" );
	
	maps\mp\gametypes\_hostmigration::waitLongDurationWithHostMigrationPause( duration );
	
	foreach ( player in level.players )
	{
		if ( player == owner )
			continue;
		
		if ( player _hasPerk( "specialty_localjammer" ) )
			player RadarJamOn();
	}
	
	level.empPlayer = undefined;
	level notify ( "emp_update" );
	level notify ( "emp_ended" );
}

empPlayerFFADisconnect()
{
	level endon ( "EMP_JamPlayers" );	
	level endon ( "emp_ended" );
	
	self waittill( "disconnect" );
	level notify ( "emp_update" );
}

empEffects()
{
	foreach( player in level.players )
	{
		playerForward = anglestoforward( player.angles );
		playerForward = ( playerForward[0], playerForward[1], 0 );
		playerForward = VectorNormalize( playerForward );
	
		empDistance = 20000;

		empEnt = Spawn( "script_model", player.origin + ( 0, 0, 8000 ) + Vector_Multiply( playerForward, empDistance ) );
		empEnt setModel( "tag_origin" );
		empEnt.angles = empEnt.angles + ( 270, 0, 0 );
		empEnt thread empEffect( player );
	}
}

empEffect( player )
{
	player endon( "disconnect" );

	wait( 0.5 );
	PlayFXOnTagForClients( level._effect[ "emp_flash" ], self, "tag_origin", player );
}

EMP_TeamTracker()
{
	level endon ( "game_ended" );
	
	for ( ;; )
	{
		level waittill_either ( "joined_team", "emp_update" );
		
		foreach ( player in level.players )
		{
			if ( player.team == "spectator" )
				continue;
				
			player setEMPJammed( level.teamEMPed[player.team] );
		}
	}
}


EMP_PlayerTracker()
{
	level endon ( "game_ended" );
	
	for ( ;; )
	{
		level waittill_either ( "joined_team", "emp_update" );
		
		foreach ( player in level.players )
		{
			if ( player.team == "spectator" )
				continue;
				
			if ( isDefined( level.empPlayer ) && level.empPlayer != player )
				player setEMPJammed( true );
			else
				player setEMPJammed( false );				
		}
	}
}

destroyActiveVehicles( attacker )
{
	if ( isDefined( attacker ) )
	{
		foreach ( heli in level.helis )
			radiusDamage( heli.origin, 384, 5000, 5000, attacker );
	
		foreach ( littleBird in level.littleBird )
			radiusDamage( littleBird.origin, 384, 5000, 5000, attacker );
		
		foreach ( turret in level.turrets )
			radiusDamage( turret.origin, 16, 5000, 5000, attacker );
	
		foreach ( rocket in level.rockets )
			rocket notify ( "death" );
		
		if ( level.teamBased )
		{
			foreach ( uav in level.uavModels["allies"] )
				radiusDamage( uav.origin, 384, 5000, 5000, attacker );
	
			foreach ( uav in level.uavModels["axis"] )
				radiusDamage( uav.origin, 384, 5000, 5000, attacker );
		}
		else
		{	
			foreach ( uav in level.uavModels )
				radiusDamage( uav.origin, 384, 5000, 5000, attacker );
		}
		
		if ( isDefined( level.ac130player ) )
			radiusDamage( level.ac130.planeModel.origin+(0,0,10), 1000, 5000, 5000, attacker );
	}
	else
	{
		foreach ( heli in level.helis )
			radiusDamage( heli.origin, 384, 5000, 5000 );
	
		foreach ( littleBird in level.littleBird )
			radiusDamage( littleBird.origin, 384, 5000, 5000 );
		
		foreach ( turret in level.turrets )
			radiusDamage( turret.origin, 16, 5000, 5000 );
	
		foreach ( rocket in level.rockets )
			rocket notify ( "death" );
		
		if ( level.teamBased )
		{
			foreach ( uav in level.uavModels["allies"] )
				radiusDamage( uav.origin, 384, 5000, 5000 );
	
			foreach ( uav in level.uavModels["axis"] )
				radiusDamage( uav.origin, 384, 5000, 5000 );
		}
		else
		{	
			foreach ( uav in level.uavModels )
				radiusDamage( uav.origin, 384, 5000, 5000 );
		}
		
		if ( isDefined( level.ac130player ) )
			radiusDamage( level.ac130.planeModel.origin+(0,0,10), 1000, 5000, 5000 );
	}
}

ALBDelete()
{
   self waittill("helicopter_done");
   self delete();
}
MakeHeli(SPoint,forward,owner,b,lifeId)
{
   if(!isDefined(b))b=false;
   if(!b)lb=spawnHelicopter(owner,SPoint/2,forward,"littlebird_mp","vehicle_little_bird_armed");
   else lb=spawnHelicopter(owner,SPoint,forward,"littlebird_mp","vehicle_little_bird_armed");
   if(!isDefined(lb))return;
   lb.owner=owner;
   lb.team=owner.team;
   lb.pers["team"]=owner.team;
   mgTurret1=spawnTurret("misc_turret",lb.origin,"pavelow_minigun_mp");
   mgTurret1.lifeId = lifeid;
   mgTurret1 setModel("weapon_minigun");
   mgTurret1 linkTo(lb,"tag_minigun_attach_right",(0,0,0),(0,0,0));
   mgTurret1.owner=owner;
   mgTurret1.team=owner.team;
   mgTurret1 makeTurretInoperable();
   mgTurret1 SetDefaultDropPitch(8);
   mgTurret1 SetRightArc(30);
   mgTurret1 SetLeftArc(30);
   mgTurret1 SetBottomArc(75);
   mgTurret1 SetTurretMinimapVisible(0);
   mgTurret1.killCamEnt=lb;
   mgTurret1 SetSentryOwner(owner);
   mgTurret1.pers["team"]=owner.team;
   mgTurret2=spawnTurret("misc_turret",lb.origin,"pavelow_minigun_mp");
   mgTurret2.lifeId = lifeid;
   mgTurret2 setModel("weapon_minigun");
   mgTurret2 linkTo(lb,"tag_minigun_attach_left",(0,0,0),(0,0,0));
   mgTurret2.owner=owner;
   mgTurret2.team=owner.team;
   mgTurret2 makeTurretInoperable();
   mgTurret2 SetDefaultDropPitch(8);
   mgTurret2 SetRightArc(30);
   mgTurret2 SetLeftArc(30);
   mgTurret2 SetBottomArc(75);
   mgTurret2.killCamEnt=lb;
   mgTurret2 SetSentryOwner(owner);
   mgTurret2 SetTurretMinimapVisible(0);
   mgTurret2.pers["team"]=owner.team;
   if(level.teamBased)
   {
      mgTurret1 setTurretTeam(owner.team);
      mgTurret2 setTurretTeam(owner.team);
   }
   lb.mg1=mgTurret1;
   lb.mg2=mgTurret2;
   return lb;
}
AttackLittlebird( lifeId )
{
   owner=self;
   dropSite=owner.origin;
   dropYaw=randomInt(360);
   flyHeight = self maps\mp\killstreaks\_airdrop::getFlyHeightOffset( dropSite );
   pathGoal = dropSite * (1,1,0) +  (0,0,flyHeight);
   pathStart = getPathStart( pathGoal, dropYaw );
   heliOrigin=pathStart;
   heliAngles=vectorToAngles( pathGoal - pathStart );
   lb=MakeHeli(heliOrigin,heliAngles,owner,1,lifeId);
   if(!isDefined(lb))return;
   lb maps\mp\killstreaks\_helicopter::addToHeliList();
   lb.zOffset=(0,0,lb getTagOrigin("tag_origin")[2]-lb getTagOrigin("tag_ground")[2]);
   lb.attractor=Missile_CreateAttractorEnt(lb,level.heli_attract_strength,level.heli_attract_range);
   lb.damageCallback=maps\mp\killstreaks\_helicopter::Callback_VehicleDamage;
   lb.maxhealth=level.heli_maxhealth*2;
   lb.team=owner.team;
   lb.attacker=undefined;
   lb.currentstate="ok";
   lb thread heli_flare_monitor();
   lb thread maps\mp\killstreaks\_helicopter::heli_leave_on_disconnect(owner);
   lb thread maps\mp\killstreaks\_helicopter::heli_leave_on_changeTeams(owner);
   lb thread maps\mp\killstreaks\_helicopter::heli_leave_on_gameended(owner);
   lb thread maps\mp\killstreaks\_helicopter::heli_leave_on_spawned(owner);
   lb thread maps\mp\killstreaks\_helicopter::heli_damage_monitor();
   lb thread maps\mp\killstreaks\_helicopter::heli_health();
   lb thread maps\mp\killstreaks\_helicopter::heli_existance();
   lb thread maps\mp\killstreaks\_airdrop::heliDestroyed();
   lb thread LBLookAtEnemies();
   lb endon("helicopter_done");
   lb endon("crashing");
   lb endon("leaving");
   lb endon("death");
   lb thread heli_leave_on_timeou(90);
   lb thread deleteLBTurrets();
   lb.mg1 setMode("auto_nonai");
   lb.mg1 thread setry_attackTargets();
   lb.mg2 setMode("auto_nonai");
   lb.mg2 thread setry_attackTargets();
   lb thread ShootLBJavi(owner);
   lb Vehicle_SetSpeed( 75, 40 );
   lb SetYawSpeed( 180, 180, 180, .3 );
   lb setVehGoalPos(pathGoal + (51, 0, 501), 1);
   wait 3;
   lb maps\mp\killstreaks\_helicopter::heli_reset();
   lb thread LBHuntEnemies();
   lb thread DropLBPackage(owner);
}
heli_leave_on_timeou(T)
{
   self endon("death");
   self endon("helicopter_done");
   maps\mp\gametypes\_hostmigration::waitLongDurationWithHostMigrationPause(T);
   M=maps\mp\gametypes\_spawnlogic::findBoxCenter(level.spawnMins,level.spawnMaxs);
   level notify("chopGone");
   self.mg1 notify("helicopter_done");
   self.mg2 notify("helicopter_done");
   self.mg1 notify("leaving");
   self.mg2 notify("leaving");
   self.mg1 setMode("manual");
   self.mg2 setMode("manual");
   self thread maps\mp\killstreaks\_helicopter::heli_leave();
}
deleteLBTurrets()
{
   self waittill("helicopter_done");
   self.mg1 delete();
   self.mg2 delete();
}
DropLBPackage(owner)
{
   self endon("death");
   self endon("helicopter_done");
   level endon("game_ended");
   self endon("crashing");
   self endon("leaving");
   waittime=15;
   wait 5;
   for(;;)
   {
      wait(waittime);
      flyHeight=self maps\mp\killstreaks\_airdrop::getFlyHeightOffset(self.origin);
      self thread maps\mp\killstreaks\_airdrop::dropTheCrate(self.origin+(0,0,-110),"airdrop_mega",flyHeight,false,undefined,self.origin+(0,0,-110));
      self notify("drop_crate");
   }
}
ShootLBJavi(owner)
{
   self endon("death");
   self endon("helicopter_done");
   level endon("game_ended");
   self endon("crashing");
   self endon("leaving");
   waittime=7;
   if ( !bulletTracePassed(self getTagOrigin( "tag_origin" ), self getTagOrigin( "tag_origin" )-(0,0,200), false, self )  )
   {
	zOffset = (0,0,70);
   }
   else
   {
	zOffset = (0,0,-160);
   }

   for(;;)
   {
      wait 1;
      AimedPlayer=undefined;
      foreach(player in level.players)
      {
         if((player==owner)||(!isAlive(player))||(level.teamBased&&owner.pers["team"]==player.pers["team"])||(!bulletTracePassed(self getTagOrigin("tag_origin")+zOffset,player getTagOrigin("back_mid"),0,self)))
		continue;

	//ONLY targetting players with cold blooded so continue if they do *NOT* have the perk (this is the opposite of most other foreach loops used by killstreaks)
	if ( !player _hasPerk( "specialty_coldblooded" ) )
				continue;
	 
	if( !self maps\mp\killstreaks\_helicopter::missile_target_sight_check( player ) )
		continue;

	if ( isdefined( player.spawntime ) && ( gettime() - player.spawntime )/1000 <= 5 )
		continue;

	if ( self maps\mp\killstreaks\_harrier::checkForFriendlies( player, 512 ) )
		continue;

	if ( !bulletTracePassed(player getTagOrigin( "j_head" ), player getTagOrigin( "j_head" )+(0,0,555), false, player )  )
		continue;

	if ( distance( player.origin, self.origin ) > 2048 )
		continue;
	
	if ( Distance2D( player.origin , self.origin ) < 768 )
		continue;

         if(isDefined(AimedPlayer))
         {
            if(closer(self getTagOrigin("tag_origin"),player getTagOrigin("back_mid"),AimedPlayer getTagOrigin("back_mid")))
		AimedPlayer=player;
         }
         else
         {
            AimedPlayer=player;
         }
      }
		if ( isDefined( level.helis ) )
		{
			foreach( heli in level.helis )
			{
				if( !isDefined( heli ) )
					continue;

				if( !self maps\mp\killstreaks\_helicopter::missile_target_sight_check( heli ) )
					continue;
			
				if ( (level.teamBased && heli.team != self.team) || (!level.teamBased && heli.owner != self.owner) )
				{
					AimLocation=self getPathEnd();
				        Angle=VectorToAngles(AimLocation-self getTagOrigin("tag_origin"));
					rocket = MagicBullet("stinger_mp",self getTagOrigin("tag_origin")+zOffset,AimLocation,owner);
					level notify( "stinger_fired", self, rocket, heli );
					rocket Missile_SetFlightmodeDirect();
					rocket Missile_SetTargetEnt( heli );
					while ( isDefined( rocket ) )
						wait ( 0.5 );
				}
			}
		}

		if ( isDefined( level.UAVModels[level.otherTeam[self.team]] ) )
		{
			foreach( uav in level.UAVModels[level.otherTeam[self.team]] )
			{
				if( !isDefined( uav ) )
					continue;
				
				if( !self maps\mp\killstreaks\_helicopter::missile_target_sight_check( uav ) )
					continue;				

				if ( (level.teamBased && uav.team != self.team) || (!level.teamBased && uav.owner != self.owner) )
				{
					AimLocation=self getPathEnd();
				        Angle=VectorToAngles(AimLocation-self getTagOrigin("tag_origin"));
					rocket = MagicBullet("stinger_mp",self getTagOrigin("tag_origin")+zOffset,AimLocation,owner);
					rocket Missile_SetFlightmodeDirect();
					rocket Missile_SetTargetEnt( uav );
					while ( isDefined( rocket ) )
						wait ( 0.5 );
				}
			}
		}

		if ( isDefined( level.littlebird ) )
		{
			foreach( littlebird in level.littlebird )
			{
				if( !isDefined( littlebird ) )
					continue;

				if( !self maps\mp\killstreaks\_helicopter::missile_target_sight_check( littlebird ) )
					continue;
				
				if ( (level.teamBased && littlebird.team != self.team) || (!level.teamBased && littlebird.owner != self.owner) )
				{
					AimLocation=self getPathEnd();
				        Angle=VectorToAngles(AimLocation-self getTagOrigin("tag_origin"));
					rocket = MagicBullet("stinger_mp",self getTagOrigin("tag_origin")+zOffset,AimLocation,owner);
					rocket Missile_SetFlightmodeDirect();
					rocket Missile_SetTargetEnt( littlebird );
					while ( isDefined( rocket ) )
						wait ( 0.5 );
				}
			}
		}

		if ( isDefined( level.ac130player ) && level.ac130player.team != self.team && isAlive( level.ac130player ) )
		{	
			AimLocation=self getPathEnd();
			Angle=VectorToAngles(AimLocation-self getTagOrigin("tag_origin"));
			rocket = MagicBullet("stinger_mp",self getTagOrigin("tag_origin")+zOffset,AimLocation,owner);
			level notify( "stinger_fired", self, rocket, level.ac130.planeModel );
			rocket Missile_SetFlightmodeDirect();
			rocket Missile_SetTargetEnt( level.ac130.planeModel );
			while ( isDefined( rocket ) )
				wait ( 0.5 );
		}

      if(isDefined(AimedPlayer))
      {
         AimLocation=(AimedPlayer getTagOrigin("back_mid"));
         Angle=VectorToAngles(AimLocation-self getTagOrigin("tag_origin"));
         MagicBullet("rpg_mp",self getTagOrigin("tag_origin")+zOffset,AimLocation,owner);
         wait 0.2;
         MagicBullet("rpg_mp",self getTagOrigin("tag_origin")+zOffset,AimLocation,owner);
	wait(waittime);
      }
   }
}
setry_attackTargets()
{
   self endon("death");
   self endon("helicopter_done");
   level endon("game_ended");
   for(;;)
   {
      self waittill("turretstatechange");
      if(self isFiringTurret())
	self thread setry_burstFireStart();
      else 
	self thread setry_burstFireStop();
   }
}
setry_burstFireStart()
{
   self endon("death");
   self endon("stop_shooting");
   self endon("leaving");
   level endon("game_ended");
   for(;;)
   {
      for(i=0;i<80;i++)
      {
         targetEnt=self getTurretTarget(false);
         if(isDefined(targetEnt))
		self shootTurret();
         wait .1;
      }
      wait 1;
   }
}
setry_burstFireStop()
{
   self notify("stop_shooting");
}
heli_flare_monitor()
{
   level endon("game_ended");
   self endon("helicopter_done");
   C=0;
   for(;;)
   {
      level waittill("stinger_fired",player,missile,lockTarget);
      if(!IsDefined(lockTarget)||(lockTarget!=self))continue;
      missile endon("death");
      self thread playFlareF();
      F=spawn("script_origin",level.ac130.planemodel.origin);
      F.angles=level.ac130.planemodel.angles;
      F moveGravity((0, 0, 0),5.0);
      F thread dAT(5.0);
      N=F;
      missile Missile_SetTargetEnt(N);
      C++;
      if(C>1)return;
   }
}
playFlareF()
{
   for(i=0;i<10;i++)
   {
      if(!isDefined(self))return;
      PlayFXOnTag(level._effect["ac130_flare"],self,"tag_origin");
      wait .15;
   }
}
dAT(d)
{
   wait(d);
   self delete();
}
LBLookAtEnemies()
{
        level endon("game_ended");
        self endon("helicopter_done");
	self endon("crashing");
	self endon("death");
	self endon( "leaving" );

	while ( 1 )
	{
		self thread maps\mp\killstreaks\_harrier::harrierGetTargets();
		wait 1;
	}
}
LBHuntEnemies()
{
        level endon("game_ended");
        self endon("helicopter_done");
	self endon("crashing");
	self endon("death");
	self endon( "leaving" );

	for ( ;; )
	{
		newpos =  self GetNewPoint(self.origin); //crazy blocking call
		self setVehGoalPos( newpos, 1 );
		self waittill ("goal");	
		wait( randomIntRange( 0.5, 1) );
	}
}

getNewPoint( pos, targ )
{
	self endon("death");
	self endon( "leaving" );
        level endon("game_ended");
        self endon("helicopter_done");
	
	enemyPoints = [];
	teamPoints = [];
	spawnPoints = []; 
	bombPoints = [];

	defenseOnly = 0;
	if(getdvar("mapname")=="mp_highrise")
		defenseOnly = 1;
	if(getdvar("mapname")=="mp_terminal")
		defenseOnly = 1;
	if(getdvar("mapname")=="mp_vacant")
		defenseOnly = 1;

	for( i = 1 ; i <= 100000 ; i++ )
	{
		
		foreach( player in level.players )
		{
			if ( coinToss() )
			        continue;
			
			if ( !isalive( player ) || player.sessionstate != "playing" )
				continue;
		
			//check if they are inside and skip them if they are
			if ( !bulletTracePassed(player getTagOrigin( "j_head" ), player getTagOrigin( "j_head" )+(0,0,555), false, player )  )
				continue;

			if ( isDefined( player.spawntime ) && ( getTime() - player.spawntime )/1000 <= 2 )
				continue;

			if ( distance( player.origin, self.origin ) > 8192 )
				continue;

			if ( !level.teambased || player.team != self.team )
				enemyPoints[enemyPoints.size] = player.origin;
			
			if ( player.team == self.team )
				teamPoints[teamPoints.size] = player.origin;
		}

		foreach( spawnpoint in level.teamSpawnPoints[level.otherTeam[self.team]] )
		{
			if ( coinToss() )
			        continue;

			if ( distance( spawnpoint.sightTracePoint, self.origin ) > 4096 )
				continue;

			//check if they are inside and skip them if they are
			if ( !bulletTracePassed(spawnpoint.sightTracePoint,spawnpoint.sightTracePoint+(0,0,555), false, undefined )  )
				continue;

			spawnPoints[spawnPoints.size] = spawnpoint.sightTracePoint;
		}

		foreach( bombpoint in level.bombZones )
		{
			if ( coinToss() )
			        continue;

			if ( distance( bombpoint.trigger.origin, self.origin ) > 4096 )
				continue;

			//check if they are inside and skip them if they are
			if ( !bulletTracePassed(bombpoint.trigger.origin,bombpoint.trigger.origin+(0,0,555), false, undefined )  )
				continue;

			bombPoints[bombPoints.size] = bombpoint.trigger.origin;
		}

		if ( bombPoints.size > 0 )
		{
			gotoPoint = bombPoints[randomInt(bombPoints.size)];
			
			pointX = RandomFloatRange( gotoPoint[0]-1000, gotoPoint[0]+1000 );
			pointY = RandomFloatRange( gotoPoint[1]-1000, gotoPoint[1]+1000 );
		}
		else if ( enemyPoints.size > 0 && defenseOnly != 1 )
		{
			
			gotoPoint = enemyPoints[randomInt(enemyPoints.size)];

			pointX = RandomFloatRange( gotoPoint[0]-1000, gotoPoint[0]+1000 );
			pointY = RandomFloatRange( gotoPoint[1]-1000, gotoPoint[1]+1000 );
		}
		else if ( spawnPoints.size > 0 )
		{
			gotoPoint = spawnpoints[randomInt(spawnpoints.size)];
			
			pointX = RandomFloatRange( gotoPoint[0]-1000, gotoPoint[0]+1000 );
			pointY = RandomFloatRange( gotoPoint[1]-1000, gotoPoint[1]+1000 );
		}
		else if ( teamPoints.size > 0 )
		{
			gotoPoint = teamPoints[randomInt(teamPoints.size)];
			
			pointX = gotoPoint[0];
			pointY = gotoPoint[1];
		}
		else
		{
			center = level.mapCenter;
			movementDist = ( level.mapSize / 6 ) - 200; 
		
			pointX = RandomFloatRange( center[0]-movementDist, center[0]+movementDist );
			pointY = RandomFloatRange( center[1]-movementDist, center[1]+movementDist );
		}
		
		newHeight = self getCorrectHeight( pointX, PointY, 20+i );
	
		point =  traceNewPoint( pointX, PointY, newHeight );
		
		if ( point != 0 )
			return point;
			
		wait 0.1;
	}
}	

getCorrectHeight( x, y, rand )
{
	offGroundHeight = 650;	
	if(isDefined(self.heliType))
		offGroundHeight *=2;
	groundHeight = self maps\mp\killstreaks\_harrier::traceGroundPoint(x,y);
	trueHeight = groundHeight + offGroundHeight;
	
	if( isDefined( level.airstrikeHeightScale ) && trueHeight < ( 850 * level.airstrikeHeightScale ) )
		trueHeight = ( 950 * level.airstrikeHeightScale );
	
	trueHeight += RandomInt( rand );
	
	return trueHeight;
}

traceNewPoint(x,y,z)
{
	self endon("death");
	self endon( "leaving" );
	level endon("game_ended");
        self endon("helicopter_done");
	
		
	for( i = 1 ; i <= 10 ; i++ )
	{

		pointX = RandomFloatRange( x-400, x+400 );
		pointY = RandomFloatRange( y-400, y+400 );
		pointZ = RandomFloatRange( z-300, z );
		
		switch( i )
		{
			case 1:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 2:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 3:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 4:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 5:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 6:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 7:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 8:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 9:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			case 10:
				trc = BulletTrace( self.origin, (pointX,pointY,pointZ), false, self );
				break;
			default:
				trc = BulletTrace( self.origin, (x,y,z), false, self );
		}
		
		if ( trc["surfacetype"] != "none" )
		{	
			return 0;
		}
		
		wait(0.05);		
	}				
	
	pathGoal = ( x, y, z );
	return pathGoal;
}

getPathStart( coord, yaw )
{
	pathRandomness = 100;
	lbHalfDistance = 7500;

	direction = (0,yaw,0);

	startPoint = coord + vector_multiply( anglestoforward( direction ), -1 * lbHalfDistance );
	startPoint += ( (randomfloat(2) - 1)*pathRandomness, (randomfloat(2) - 1)*pathRandomness, 0 );
	
	return startPoint;
}

getPathEnd()
{

	heightEnt = GetEnt( "airstrikeheight", "targetname" );
	
	if ( isDefined( heightEnt ) )
		trueHeight = heightEnt.origin[2];
	else if( isDefined( level.airstrikeHeightScale ) )
		trueHeight = 850 * level.airstrikeHeightScale;
	else
		trueHeight = 850;

	yaw = self.angles[1];	
	direction = (0,yaw,0);

	endPoint = self.origin + vector_multiply( anglestoforward( direction ), 12500 );
	endPoint += (randomfloat(2) - 1, randomfloat(2) - 1, trueHeight );
	return endPoint;
}
