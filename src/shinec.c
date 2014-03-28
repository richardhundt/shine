
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int luaopen_lpeg (lua_State *L);

static int traceback(lua_State *L) {
    lua_getfield(L, LUA_GLOBALSINDEX, "debug");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return 1;
    }
    lua_getfield(L, -1, "traceback");
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 2);
        return 1;
    }

    lua_pushvalue(L, 1);    /* pass error message */
    lua_pushinteger(L, 2);  /* skip this function and traceback */
    lua_call(L, 2, 1);      /* call debug.traceback */

    return 1;
}

int main(int argc, char *argv[]) {
  lua_State *L;
  int i, status;

  L = luaL_newstate();
  if (L == NULL) {
    fprintf(stderr, "PANIC: failed to create main state!\n");
    return 1;
  }

  luaL_openlibs(L);
  luaL_findtable(L, LUA_REGISTRYINDEX, "_PRELOAD", 1);
  lua_pushcfunction(L, luaopen_lpeg);
  lua_setfield(L, -2, "lpeg");
  lua_pop(L, 1);

  lua_createtable(L, argc + 1, 0);
  lua_pushstring(L, "shinec");
  lua_rawseti(L, -2, 0);

  for (i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i);
  }
  lua_setglobal(L, "arg");

  lua_pushcfunction(L, traceback);
  lua_getglobal(L, "require");
  lua_pushliteral(L, "shinec");
  status = lua_pcall(L, 1, 1, -3);

  if (status) {
    fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
    lua_close(L);
    return 1;
  }

  lua_getfield(L, -1, "start");
  lua_call(L, 0, 0);

  lua_close(L);
  return 0;
}

