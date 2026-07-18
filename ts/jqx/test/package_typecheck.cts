import bind = require("@shina1024/jqx/bind");
import root = require("@shina1024/jqx");

const directOut = root.run(".", { user: { name: "a" } });
const directOutCheck: root.JqxResult<root.Json[], root.JqxRuntimeError> = directOut;
void directOutCheck;

const compiled = root.compile(".user.name");
const compiledCheck: root.JqxResult<
  root.CompiledFilter<".user.name">,
  root.JqxRuntimeError
> = compiled;
void compiledCheck;

declare const bindingRuntime: bind.JqxJsonTextRuntime;
const jqx = bind.bindRuntime(bindingRuntime);
const boundRunCheck: Promise<root.JqxResult<root.Json[], root.JqxRuntimeError>> = jqx.run(".", {
  user: { name: "a" },
});
void boundRunCheck;
type BoundRuntimeHasCompile = "compile" extends keyof typeof jqx ? true : false;
const boundRuntimeHasCompile: BoundRuntimeHasCompile = false;
void boundRuntimeHasCompile;
