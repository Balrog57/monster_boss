var TC=1,TF=2,TM=3,TT=4,TN={1:"Cleric",2:"Fighter",3:"Mage",4:"Thief"};
var BOSSES=[{id:"BMA001",n:"Draculord",xp:900,tr:[TC]},{id:"BMA002",n:"Xyzax",xp:750,tr:[TC]},{id:"BMA003",n:"King Croak",xp:800,tr:[TF]},{id:"BMA004",n:"Robobo",xp:400,tr:[TF]},{id:"BMA005",n:"Cerebellus",xp:650,tr:[TM]},{id:"BMA006",n:"Seducia",xp:600,tr:[TM]},{id:"BMA007",n:"Cleopatra",xp:850,tr:[TT]},{id:"BMA008",n:"Gorgona",xp:500,tr:[TT]}];
var ROOMS=[{id:"BMA009",n:"Dark Altar",a:0,t:"trap",d:1,tr:[TC,TC],q:3},{id:"BMA010",n:"Open Grave",a:0,t:"trap",d:2,tr:[TC],q:2},{id:"BMA011",n:"Specters Sanctum",a:0,t:"monster",d:2,tr:[TC],q:3},{id:"BMA012",n:"Succubus Spa",a:0,t:"monster",d:1,tr:[TC],q:3},{id:"BMA013",n:"Dracolich Lair",a:1,t:"monster",d:3,tr:[TC],q:2},{id:"BMA014",n:"Vampire Bordello",a:1,t:"monster",d:3,tr:[TC],q:2},{id:"BMA015",n:"Goblin Armory",a:0,t:"monster",d:1,tr:[TF,TF],q:3},{id:"BMA016",n:"Golem Factory",a:0,t:"monster",d:2,tr:[TF],q:3},{id:"BMA017",n:"Minotaurs Maze",a:0,t:"monster",d:0,tr:[TF],q:2},{id:"BMA018",n:"Neanderthal Cave",a:0,t:"monster",d:3,tr:[TF],q:3},{id:"BMA019",n:"Beast Menagerie",a:1,t:"monster",d:4,tr:[TF],q:2},{id:"BMA020",n:"Monsters Ballroom",a:1,t:"monster",d:0,tr:[TF],q:2},{id:"BMA021",n:"Brainsucker Hive",a:0,t:"monster",d:2,tr:[TM],q:3},{id:"BMA022",n:"Dark Laboratory",a:0,t:"trap",d:1,tr:[TM,TM],q:3},{id:"BMA023",n:"Haunted Library",a:0,t:"trap",d:1,tr:[TM],q:2},{id:"BMA024",n:"Witchs Kitchen",a:0,t:"monster",d:1,tr:[TM],q:3},{id:"BMA025",n:"All-Seeing Eye",a:1,t:"trap",d:3,tr:[TM],q:2},{id:"BMA026",n:"Ligers Den",a:1,t:"monster",d:2,tr:[TM],q:2},{id:"BMA027",n:"Bottomless Pit",a:0,t:"trap",d:1,tr:[TT],q:3},{id:"BMA028",n:"Boulder Ramp",a:0,t:"trap",d:1,tr:[TT],q:2},{id:"BMA029",n:"Dizzygas Hallway",a:0,t:"trap",d:1,tr:[TT],q:3},{id:"BMA030",n:"Jackpot Stash",a:0,t:"trap",d:1,tr:[TT,TT],q:3},{id:"BMA031",n:"Recycling Center",a:1,t:"trap",d:3,tr:[TT],q:2},{id:"BMA032",n:"The Crushinator",a:1,t:"trap",d:2,tr:[TT],q:2},{id:"BMA033",n:"Centipede Tunnel",a:0,t:"monster",d:1,tr:[TF,TM],q:2},{id:"BMA034",n:"Construction Zone",a:0,t:"trap",d:1,tr:[TF,TT],q:2},{id:"BMA035",n:"Dragon Hatchery",a:0,t:"monster",d:0,tr:[TC,TM,TF,TT],q:3},{id:"BMA036",n:"Mimic Vault",a:0,t:"trap",d:1,tr:[TM,TT],q:2},{id:"BMA037",n:"Monstrous Monument",a:0,t:"trap",d:1,tr:[TC,TF],q:2},{id:"BMA038",n:"Torture Chamber",a:0,t:"trap",d:1,tr:[TC,TT],q:2},{id:"BMA039",n:"Zombie Prison",a:0,t:"monster",d:1,tr:[TC,TM],q:2}];
var SPELLS=[{id:"BMA040",n:"Annihilator",c:3,q:2},{id:"BMA041",n:"Assassin",c:3,q:2},{id:"BMA042",n:"Cave-In",c:4,q:2},{id:"BMA043",n:"Counterspell",c:2,q:2},{id:"BMA044",n:"Exhaustion",c:4,q:1},{id:"BMA045",n:"Fear",c:1,q:2},{id:"BMA046",n:"Freeze",c:2,q:4},{id:"BMA047",n:"Giant Size",c:3,q:2},{id:"BMA048",n:"Jeopardy",c:2,q:2},{id:"BMA049",n:"Kobold Strike",c:2,q:1},{id:"BMA050",n:"Motivation",c:3,q:2},{id:"BMA051",n:"Princess in Peril",c:1,q:2},{id:"BMA052",n:"Soul Harvest",c:1,q:1},{id:"BMA053",n:"Teleportation",c:1,q:2},{id:"BMA054",n:"Trepidation",c:2,q:1},{id:"BMA055",n:"Zombie Attack",c:1,q:2}];
var OHEROES=[{id:"BMA056",n:"Cleric 1",cl:TC,hp:4},{id:"BMA057",n:"Cleric 2",cl:TC,hp:4},{id:"BMA058",n:"Cleric 3",cl:TC,hp:6},{id:"BMA059",n:"Cleric 4",cl:TC,hp:6},{id:"BMA060",n:"Cleric 5",cl:TC,hp:8},{id:"BMA061",n:"Cleric 6",cl:TC,hp:8},{id:"BMA062",n:"Fighter 1",cl:TF,hp:4},{id:"BMA063",n:"Fighter 2",cl:TF,hp:4},{id:"BMA064",n:"Fighter 3",cl:TF,hp:6},{id:"BMA065",n:"Fighter 4",cl:TF,hp:6},{id:"BMA066",n:"Fighter 5",cl:TF,hp:8},{id:"BMA067",n:"Fighter 6",cl:TF,hp:8},{id:"BMA068",n:"Mage 1",cl:TM,hp:4},{id:"BMA069",n:"Mage 2",cl:TM,hp:4},{id:"BMA070",n:"Mage 3",cl:TM,hp:6},{id:"BMA071",n:"Mage 4",cl:TM,hp:6},{id:"BMA072",n:"Mage 5",cl:TM,hp:8},{id:"BMA073",n:"Mage 6",cl:TM,hp:8},{id:"BMA074",n:"Thief 1",cl:TT,hp:4},{id:"BMA075",n:"Thief 2",cl:TT,hp:4},{id:"BMA076",n:"Thief 3",cl:TT,hp:6},{id:"BMA077",n:"Thief 4",cl:TT,hp:6},{id:"BMA078",n:"Thief 5",cl:TT,hp:8},{id:"BMA079",n:"Thief 6",cl:TT,hp:8},{id:"BMA080",n:"The Fool",cl:0,hp:2}];
var EHEROES=[{id:"BMA081",n:"Epic Cleric 1",cl:TC,hp:11},{id:"BMA082",n:"Epic Cleric 2",cl:TC,hp:11},{id:"BMA083",n:"Epic Cleric 3",cl:TC,hp:13},{id:"BMA084",n:"Epic Cleric 4",cl:TC,hp:13},{id:"BMA085",n:"Epic Fighter 1",cl:TF,hp:11},{id:"BMA086",n:"Epic Fighter 2",cl:TF,hp:11},{id:"BMA087",n:"Epic Fighter 3",cl:TF,hp:13},{id:"BMA088",n:"Epic Fighter 4",cl:TF,hp:13},{id:"BMA089",n:"Epic Mage 1",cl:TM,hp:11},{id:"BMA090",n:"Epic Mage 2",cl:TM,hp:11},{id:"BMA091",n:"Epic Mage 3",cl:TM,hp:13},{id:"BMA092",n:"Epic Mage 4",cl:TM,hp:13},{id:"BMA093",n:"Epic Thief 1",cl:TT,hp:11},{id:"BMA094",n:"Epic Thief 2",cl:TT,hp:11},{id:"BMA095",n:"Epic Thief 3",cl:TT,hp:13},{id:"BMA096",n:"Epic Thief 4",cl:TT,hp:13}];

function ci(id){var c=id.toLowerCase();return IMG[c]||IMG[c+"a"]||""}
function cardBG(card){var img=ci(card.id);return img?"background-image:url(data:image/jpeg;base64,"+img+")":""}

var G={
  np:2,ps:[],turn:0,phase:"menu",rd:[],sd:[],hd:[],ed:[],rdi:[],sdi:[],hdi:[],
  town:[],logs:[],bp:[],sel:-1,

  sh:function(a){var b=a.slice();for(var i=b.length-1;i>0;i--){var j=Math.floor(Math.random()*(i+1));var t=b[i];b[i]=b[j];b[j]=t}return b},
  dw:function(d){return d.length?d.pop():null},
  lg:function(m){this.logs.push(m);if(this.logs.length>60)this.logs.shift()},

  start:function(np){
    this.np=np;this.ps=[];this.turn=0;this.phase="boss";this.town=[];this.rdi=[];this.sdi=[];this.hdi=[];this.logs=[];this.sel=-1;
    var rd=[];ROOMS.forEach(function(r){for(var i=0;i<r.q;i++)rd.push(r)});this.rd=this.sh(rd);
    var sd=[];SPELLS.forEach(function(s){for(var i=0;i<s.q;i++)sd.push(s)});this.sd=this.sh(sd);
    var hd=[];OHEROES.forEach(function(h){hd.push({id:h.id,n:h.n,cl:h.cl,hp:h.hp,epic:0,wounds:1,souls:1,chp:h.hp})});
    EHEROES.forEach(function(h){hd.push({id:h.id,n:h.n,cl:h.cl,hp:h.hp,epic:1,wounds:2,souls:2,chp:h.hp})});
    hd=this.sh(hd);this.hd=hd.filter(function(h){return !h.epic});this.ed=hd.filter(function(h){return h.epic});
    this.bp=this.sh(BOSSES.slice()).slice(0,3);
    this.ps.push({id:0,name:"You",boss:null,dg:[],hd:[],sl:[],wd:[],ai:0,lu:0,da:[],ent:[],out:0});
    render();
  },

  pickBoss:function(b){this.ps[0].boss=b;this.phase="setup";var self=this;
    for(var i=1;i<this.np;i++){var ab=this.sh(BOSSES.slice())[0];this.ps.push({id:i,name:"AI "+i,boss:ab,dg:[],hd:[],sl:[],wd:[],ai:1,lu:0,da:[],ent:[],out:0})}
    for(var pi=0;pi<this.ps.length;pi++){var p=this.ps[pi];for(var j=0;j<5;j++){var c=self.dw(self.rd);if(c)p.hd.push({id:c.id,n:c.n,a:c.a,t:c.t,d:c.d,tr:c.tr,isR:1})}for(var j=0;j<2;j++){var c=self.dw(self.sd);if(c)p.hd.push({id:c.id,n:c.n,c:c.c,isS:1})}}
    for(var pi=0;pi<this.ps.length;pi++){var p=this.ps[pi];var rc=p.hd.filter(function(c){return c.isR});var td=rc.slice(0,2);td.forEach(function(c){p.hd.splice(p.hd.indexOf(c),1);if(c.isR)self.rdi.push(c);else self.sdi.push(c)})}
    this.lg("Game started! Boss: "+b.n);render();
  },

  build:function(hi){var p=this.ps[0];if(!p||hi<0||hi>=p.hd.length)return;
    var c=p.hd[hi];if(!c.isR){this.lg("Select a Room card!");render();return}
    if(c.a){if(p.dg.length===0){this.lg("Need a room to replace!");render();return}
      var last=p.dg[p.dg.length-1];if(!c.tr.some(function(t){return last.tr.indexOf(t)>=0})){this.lg("Must share treasure type!");render();return}
      this.rdi.push(last);p.dg[p.dg.length-1]=c}else{p.dg.push(c)}
    p.hd.splice(hi,1);this.sel=-1;this.lg("Built "+c.n);
    if(p.dg.length>=5&&!p.lu){p.lu=1;var s=this.dw(this.sd);if(s)p.hd.push({id:s.id,n:s.n,c:s.c,isS:1});this.lg("LEVEL UP!")}render();
  },

  cast:function(hi){var p=this.ps[0];if(!p||hi<0||hi>=p.hd.length)return;
    var s=p.hd[hi];if(!s.isS){this.lg("Select a Spell!");render();return}
    p.hd.splice(hi,1);this.sdi.push(s);this.sel=-1;this.lg("Cast "+s.n);render();
  },

  pass:function(){this.sel=-1;render()}
};

function render(){
  var el=document.getElementById("root"),h="";
  if(G.phase==="menu"){el.innerHTML='<h1>BOSS MONSTER</h1><div class="menu">'+[2,3,4].map(function(n){return '<button onclick="G.start('+n+')">'+n+" Players</button>"}).join("")+"</div>";return}
  if(G.phase==="boss"){h='<h1>Choose your Boss</h1><div class="menu">';G.bp.forEach(function(b){h+='<button style="'+cardBG(b)+';width:180px;height:250px;font-size:14px;color:#fff;text-shadow:2px 2px #000" onclick="G.pickBoss({id:&quot;'+b.id+'&quot;,n:&quot;'+b.n+'&quot;,xp:'+b.xp+',tr:['+b.tr+']})">'+b.n+"<br><br>XP:"+b.xp+"</button>"});h+="</div>";el.innerHTML=h;return}
  h+='<div style="display:flex;justify-content:space-between;margin-bottom:5px"><b>Turn '+G.turn+'</b> <span style="color:#d80">'+G.phase.toUpperCase()+"</span></div>";
  h+='<div class="board">';
  for(var pi=0;pi<G.ps.length;pi++){var pl=G.ps[pi],ts=0,tw=0;
    pl.sl.forEach(function(x){ts+=x.souls});pl.wd.forEach(function(x){tw+=x.wounds});
    h+='<div class="pa'+(pi===0?" you":"")+'"><h3>'+(pl.boss?pl.boss.n:"???")+" (P"+(pi+1)+")</h3>";
    h+='<div class="stats"><span class="s">Souls:'+ts+'</span> <span class="w">Wounds:'+tw+"</span></div>";
    h+='<div class="dung">';
    if(pi===0)h+='<div class="build" onclick="G.build(G.sel)"><span>BUILD</span></div>';
    pl.dg.forEach(function(r){h+='<div class="card" style="'+cardBG(r)+'"><div class="lb"><span class="d">'+r.d+"</span> "+r.tr.map(function(t){return TN[t]}).join("/")+"</div></div>"});
    if(pl.boss)h+='<div class="boss" style="'+cardBG(pl.boss)+'"><div class="bl">'+pl.boss.n+'</div><div class="bl">XP:'+pl.boss.xp+"</div></div>";
    h+="</div>";
    if(pi===0){h+='<div class="hand">';
      pl.hd.forEach(function(c,i){h+='<div class="card'+(G.sel===i?" sel":"")+'" style="'+cardBG(c)+'" onclick="G.sel=G.sel==='+i+'?-1:'+i+';render()"><div class="lb">'+c.n+(c.isR?" DMG:"+c.d:" SPELL")+"</div></div>"});
      h+="</div>";
      h+='<div class="acts"><button class="btn" onclick="G.build(G.sel)">Build</button><button class="btn red" onclick="G.cast(G.sel)">Spell</button><button class="btn blue" onclick="G.pass()">Pass</button></div>'}
    h+="</div>"}
  h+="</div>";
  h+='<div class="town"><h4>TOWN</h4>';G.town.forEach(function(hr){h+='<div class="hero'+(hr.epic?" epic":"")+'" style="'+cardBG(hr)+'"><div class="hl">'+hr.n+'</div><div class="hl">HP:'+hr.hp+"</div></div>"});
  if(!G.town.length)h+='<span style="color:#555;padding:5px">(empty)</span>';h+="</div>";
  h+='<div class="log">';G.logs.slice(-8).forEach(function(l){h+="<div>"+l+"</div>"});h+="</div>";
  el.innerHTML=h;
}
render();
