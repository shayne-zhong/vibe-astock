import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "../..");
const entrypoint = "deploy/container-entrypoint.sh";
const shell = process.platform === "win32"
  ? path.join(process.env.ProgramFiles ?? "C:\\Program Files", "Git", "bin", "sh.exe")
  : "sh";

function dryRun(extra: NodeJS.ProcessEnv = {}) {
  return spawnSync(shell, [entrypoint], {
    cwd: root,
    env: {
      ...process.env,
      VRA_CONTAINER_DRY_RUN: "1",
      VRA_PUBLIC_URL: "",
      RENDER_EXTERNAL_URL: "",
      RAILWAY_PUBLIC_DOMAIN: "vibe-astock.example.up.railway.app",
      PORT: "8080",
      ...extra,
    },
    encoding: "utf8",
  });
}

test("生产容器把公开端口和 Railway 域名交给远程启动器", () => {
  const result = dryRun();

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /VRA_DATA_ROOT=\/data/);
  assert.match(result.stdout, /UI_PORT=8080/);
  assert.match(result.stdout, /API_PORT=8770/);
  assert.match(result.stdout, /PUBLIC_URL=https:\/\/vibe-astock\.example\.up\.railway\.app/);
});

test("生产容器拒绝在不知道公开 HTTPS 地址时启动", () => {
  const result = dryRun({ RAILWAY_PUBLIC_DOMAIN: "" });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /VRA_PUBLIC_URL/);
});

test("生产容器直接初始化平台卷，不调用只允许仓库内数据根的 init", () => {
  const source = fs.readFileSync(path.join(root, entrypoint), "utf8");

  assert.doesNotMatch(source, /orchestrator\/src\/init\.ts/);
  assert.match(source, /mkdir -p .*runs.*knowledge.*providers.*mcp/s);
  assert.match(source, /config\.json/);
  assert.match(source, /\/app\/\.venv\/bin\/python/);
});

test("生产镜像排除私有数据、密钥和旧版构建目录", () => {
  const dockerignore = fs.readFileSync(path.join(root, ".dockerignore"), "utf8");
  for (const entry of [".env", ".env.*", ".local", ".git", ".vercel", "frontend", "node_modules", ".venv"]) {
    assert.match(dockerignore, new RegExp(`^${entry.replaceAll(".", "\\.")}\\/?$`, "m"), entry);
  }
});

test("生产镜像构建新版页面与 Python 取数层，并把数据根留给平台卷挂载", () => {
  const dockerfile = fs.readFileSync(path.join(root, "Dockerfile"), "utf8");

  assert.match(dockerfile, /npm ci --prefix orchestrator/);
  assert.match(dockerfile, /npm ci --prefix desktop/);
  assert.match(dockerfile, /npm run build --prefix desktop/);
  assert.match(dockerfile, /requirements\.txt/);
  assert.match(dockerfile, /VRA_DATA_ROOT=\/data/);
  assert.doesNotMatch(dockerfile, /^VOLUME\b/m);
  assert.match(dockerfile, /ENTRYPOINT \["\/app\/deploy\/container-entrypoint\.sh"\]/);
});
