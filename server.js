const { Server } = require("boardgame.io/server");
const { BossMonster } = require("./src/Game");
const path = require("path");
const serve = require("serve-static");

const server = Server({ games: [BossMonster] });
const staticFiles = serve(path.join(__dirname, "public"));
server.app.use(staticFiles);
server.run(8000, () => console.log("Boss Monster running on http://localhost:8000"));
