import { Game, INVALID_MOVE } from 'boardgame.io/core';

// Card data (simplified for boardgame.io)
const TC=1,TF=2,TM=3,TT=4;
const TREASURE = {1:"Cleric",2:"Fighter",3:"Mage",4:"Thief"};

const BOSSES = [
  {id:"BMA001",n:"Draculord",xp:900,tr:[TC]},{id:"BMA002",n:"Xyzax",xp:750,tr:[TC]},
  {id:"BMA003",n:"King Croak",xp:800,tr:[TF]},{id:"BMA004",n:"Robobo",xp:400,tr:[TF]},
  {id:"BMA005",n:"Cerebellus",xp:650,tr:[TM]},{id:"BMA006",n:"Seducia",xp:600,tr:[TM]},
  {id:"BMA007",n:"Cleopatra",xp:850,tr:[TT]},{id:"BMA008",n:"Gorgona",xp:500,tr:[TT]}
];

const ROOMS = [
  {id:"BMA009",n:"Dark Altar",a:false,t:"trap",d:1,tr:[TC,TC],q:3},
  {id:"BMA010",n:"Open Grave",a:false,t:"trap",d:2,tr:[TC],q:2},
  {id:"BMA011",n:"Specters Sanctum",a:false,t:"monster",d:2,tr:[TC],q:3},
  {id:"BMA012",n:"Succubus Spa",a:false,t:"monster",d:1,tr:[TC],q:3},
  {id:"BMA013",n:"Dracolich Lair",a:true,t:"monster",d:3,tr:[TC],q:2},
  {id:"BMA014",n:"Vampire Bordello",a:true,t:"monster",d:3,tr:[TC],q:2},
  {id:"BMA015",n:"Goblin Armory",a:false,t:"monster",d:1,tr:[TF,TF],q:3},
  {id:"BMA016",n:"Golem Factory",a:false,t:"monster",d:2,tr:[TF],q:3},
  {id:"BMA017",n:"Minotaurs Maze",a:false,t:"monster",d:0,tr:[TF],q:2},
  {id:"BMA018",n:"Neanderthal Cave",a:false,t:"monster",d:3,tr:[TF],q:3},
  {id:"BMA019",n:"Beast Menagerie",a:true,t:"monster",d:4,tr:[TF],q:2},
  {id:"BMA020",n:"Monsters Ballroom",a:true,t:"monster",d:0,tr:[TF],q:2},
  {id:"BMA021",n:"Brainsucker Hive",a:false,t:"monster",d:2,tr:[TM],q:3},
  {id:"BMA022",n:"Dark Laboratory",a:false,t:"trap",d:1,tr:[TM,TM],q:3},
  {id:"BMA023",n:"Haunted Library",a:false,t:"trap",d:1,tr:[TM],q:2},
  {id:"BMA024",n:"Witchs Kitchen",a:false,t:"monster",d:1,tr:[TM],q:3},
  {id:"BMA025",n:"All-Seeing Eye",a:true,t:"trap",d:3,tr:[TM],q:2},
  {id:"BMA026",n:"Ligers Den",a:true,t:"monster",d:2,tr:[TM],q:2},
  {id:"BMA027",n:"Bottomless Pit",a:false,t:"trap",d:1,tr:[TT],q:3},
  {id:"BMA028",n:"Boulder Ramp",a:false,t:"trap",d:1,tr:[TT],q:2},
  {id:"BMA029",n:"Dizzygas Hallway",a:false,t:"trap",d:1,tr:[TT],q:3},
  {id:"BMA030",n:"Jackpot Stash",a:false,t:"trap",d:1,tr:[TT,TT],q:3},
  {id:"BMA031",n:"Recycling Center",a:true,t:"trap",d:3,tr:[TT],q:2},
  {id:"BMA032",n:"The Crushinator",a:true,t:"trap",d:2,tr:[TT],q:2},
  {id:"BMA033",n:"Centipede Tunnel",a:false,t:"monster",d:1,tr:[TF,TM],q:2},
  {id:"BMA034",n:"Construction Zone",a:false,t:"trap",d:1,tr:[TF,TT],q:2},
  {id:"BMA035",n:"Dragon Hatchery",a:false,t:"monster",d:0,tr:[TC,TM,TF,TT],q:3},
  {id:"BMA036",n:"Mimic Vault",a:false,t:"trap",d:1,tr:[TM,TT],q:2},
  {id:"BMA037",n:"Monstrous Monument",a:false,t:"trap",d:1,tr:[TC,TF],q:2},
  {id:"BMA038",n:"Torture Chamber",a:false,t:"trap",d:1,tr:[TC,TT],q:2},
  {id:"BMA039",n:"Zombie Prison",a:false,t:"monster",d:1,tr:[TC,TM],q:2}
];

const SPELLS = [
  {id:"BMA040",n:"Annihilator",c:3,q:2},{id:"BMA041",n:"Assassin",c:3,q:2},
  {id:"BMA042",n:"Cave-In",c:4,q:2},{id:"BMA043",n:"Counterspell",c:2,q:2},
  {id:"BMA044",n:"Exhaustion",c:4,q:1},{id:"BMA045",n:"Fear",c:1,q:2},
  {id:"BMA046",n:"Freeze",c:2,q:4},{id:"BMA047",n:"Giant Size",c:3,q:2},
  {id:"BMA048",n:"Jeopardy",c:2,q:2},{id:"BMA049",n:"Kobold Strike",c:2,q:1},
  {id:"BMA050",n:"Motivation",c:3,q:2},{id:"BMA051",n:"Princess in Peril",c:1,q:2},
  {id:"BMA052",n:"Soul Harvest",c:1,q:1},{id:"BMA053",n:"Teleportation",c:1,q:2},
  {id:"BMA054",n:"Trepidation",c:2,q:1},{id:"BMA055",n:"Zombie Attack",c:1,q:2}
];

function shuffle(a){var b=a.slice();for(var i=b.length-1;i>0;i--){var j=Math.floor(Math.random()*(i+1));var t=b[i];b[i]=b[j];b[j]=t}return b}

export const BossMonster = {
  name: "boss-monster",

  setup: (ctx) => {
    let rd=[],sd=[],hd=[],ed=[];
    ROOMS.forEach(r=>{for(let i=0;i<r.q;i++)rd.push({...r})});
    SPELLS.forEach(s=>{for(let i=0;i<s.q;i++)sd.push({...s})});
    OHEROES.forEach(h=>hd.push({...h,epic:false,wounds:1,souls:1}));
    EHEROES.forEach(h=>ed.push({...h,epic:true,wounds:2,souls:2}));
    rd=shuffle(rd);sd=shuffle(sd);hd=shuffle(hd);ed=shuffle(ed);

    let players = {};
    for(let i=0;i<ctx.numPlayers;i++){
      players[i] = {
        boss: null, dungeon: [], hand: [], souls: [], wounds: [],
        deactivated: [], entrance: [], eliminated: false, leveledUp: false
      };
    }
    
    let bossPicks = shuffle(BOSSES).slice(0, Math.min(ctx.numPlayers+2, BOSSES.length));

    return {
      players, bossPicks,
      decks: { rooms: rd, spells: sd, heroes: hd, epics: ed,
               roomDiscard: [], spellDiscard: [], heroDiscard: [] },
      town: [], turn: 0, phase: "boss", round: 0,
      buildOrder: [], buildIndex: 0, adventureOrder: [], adventureIndex: 0,
      logs: ["Welcome to Boss Monster!"]
    };
  },

  phases: {
    boss: {
      start: true,
      moves: { pickBoss: (G, ctx, bossId) => {
        const boss = BOSSES.find(b=>b.id===bossId);
        if(!boss) return INVALID_MOVE;
        G.players[ctx.playerID].boss = boss;
        G.logs.push(ctx.playerID+" chose "+boss.n);
      }},
      next: "play",
      endIf: (G) => Object.values(G.players).every(p=>p.boss)
    },
    play: {
      moves: {
        buildRoom: (G, ctx, handIndex) => {
          const p = G.players[ctx.playerID];
          if(handIndex<0||handIndex>=p.hand.length) return INVALID_MOVE;
          const card = p.hand[handIndex];
          if(!card.isRoom) return INVALID_MOVE;
          if(card.a){
            if(p.dungeon.length===0) return INVALID_MOVE;
            const last = p.dungeon[p.dungeon.length-1];
            if(!card.tr.some(t=>last.tr.includes(t))) return INVALID_MOVE;
            G.decks.roomDiscard.push(last);
            p.dungeon[p.dungeon.length-1] = card;
          } else {
            p.dungeon.push(card);
          }
          p.hand.splice(handIndex,1);
          G.logs.push(ctx.playerID+" built "+card.n);
        },
        playSpell: (G, ctx, handIndex) => {
          const p = G.players[ctx.playerID];
          if(handIndex<0||handIndex>=p.hand.length) return INVALID_MOVE;
          const s = p.hand[handIndex];
          if(!s.isSpell) return INVALID_MOVE;
          p.hand.splice(handIndex,1);
          G.decks.spellDiscard.push(s);
          G.logs.push(ctx.playerID+" cast "+s.n);
        },
        pass: (G) => {
          G.logs.push("Pass");
        }
      }
    }
  }
};

// Basic heroes data
const OHEROES = [
  {id:"BMA056",n:"Cleric 1",cl:TC,hp:4},{id:"BMA057",n:"Cleric 2",cl:TC,hp:4},
  {id:"BMA058",n:"Cleric 3",cl:TC,hp:6},{id:"BMA059",n:"Cleric 4",cl:TC,hp:6},
  {id:"BMA060",n:"Cleric 5",cl:TC,hp:8},{id:"BMA061",n:"Cleric 6",cl:TC,hp:8},
  {id:"BMA062",n:"Fighter 1",cl:TF,hp:4},{id:"BMA063",n:"Fighter 2",cl:TF,hp:4},
  {id:"BMA064",n:"Fighter 3",cl:TF,hp:6},{id:"BMA065",n:"Fighter 4",cl:TF,hp:6},
  {id:"BMA066",n:"Fighter 5",cl:TF,hp:8},{id:"BMA067",n:"Fighter 6",cl:TF,hp:8},
  {id:"BMA068",n:"Mage 1",cl:TM,hp:4},{id:"BMA069",n:"Mage 2",cl:TM,hp:4},
  {id:"BMA070",n:"Mage 3",cl:TM,hp:6},{id:"BMA071",n:"Mage 4",cl:TM,hp:6},
  {id:"BMA072",n:"Mage 5",cl:TM,hp:8},{id:"BMA073",n:"Mage 6",cl:TM,hp:8},
  {id:"BMA074",n:"Thief 1",cl:TT,hp:4},{id:"BMA075",n:"Thief 2",cl:TT,hp:4},
  {id:"BMA076",n:"Thief 3",cl:TT,hp:6},{id:"BMA077",n:"Thief 4",cl:TT,hp:6},
  {id:"BMA078",n:"Thief 5",cl:TT,hp:8},{id:"BMA079",n:"Thief 6",cl:TT,hp:8},
  {id:"BMA080",n:"The Fool",cl:0,hp:2}
];

const EHEROES = [
  {id:"BMA081",n:"Epic Cleric 1",cl:TC,hp:11},{id:"BMA082",n:"Epic Cleric 2",cl:TC,hp:11},
  {id:"BMA083",n:"Epic Cleric 3",cl:TC,hp:13},{id:"BMA084",n:"Epic Cleric 4",cl:TC,hp:13},
  {id:"BMA085",n:"Epic Fighter 1",cl:TF,hp:11},{id:"BMA086",n:"Epic Fighter 2",cl:TF,hp:11},
  {id:"BMA087",n:"Epic Fighter 3",cl:TF,hp:13},{id:"BMA088",n:"Epic Fighter 4",cl:TF,hp:13},
  {id:"BMA089",n:"Epic Mage 1",cl:TM,hp:11},{id:"BMA090",n:"Epic Mage 2",cl:TM,hp:11},
  {id:"BMA091",n:"Epic Mage 3",cl:TM,hp:13},{id:"BMA092",n:"Epic Mage 4",cl:TM,hp:13},
  {id:"BMA093",n:"Epic Thief 1",cl:TT,hp:11},{id:"BMA094",n:"Epic Thief 2",cl:TT,hp:11},
  {id:"BMA095",n:"Epic Thief 3",cl:TT,hp:13},{id:"BMA096",n:"Epic Thief 4",cl:TT,hp:13}
];
