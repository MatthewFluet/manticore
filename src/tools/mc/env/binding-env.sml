(* binding-env.sml
 *
 * COPYRIGHT (c) 2008 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Environment for the bound-variable check.
 *)

structure BindingEnv =
  struct

    structure PT1 = ProgramParseTree.PML1
    structure PT2 = ProgramParseTree.PML2
    structure Var = ProgramParseTree.Var
    structure Map = AtomMap

    type ty_bind = PT2.ty_bind
    type var_bind = PT2.var_bind
    type mod_bind = PT2.mod_bind
    type sig_id = PT2.sig_id

    type bom_var = PT2.BOMParseTree.var_bind
    type bom_var_env = bom_var Map.map

    datatype bom_env
      = BOMEnv of {
	  varEnv : bom_var_env
        }

    val emptyBOMEnv = BOMEnv{
		  varEnv = Map.empty
		}

  (* value identifiers may be data constructors, variables, or overloaded variables. *)
    datatype val_bind
      = Con of var_bind
      | Var of var_bind

    type ty_env = ty_bind Map.map
    type var_env = val_bind Map.map
    type mod_env = mod_bind Map.map
    datatype env
      = Env of {
	     tyEnv    : ty_env,
	     varEnv   : var_env,
	     bomEnv   : bom_env,
	     modEnv   : (mod_bind * env) Map.map,
	     sigEnv   : (sig_id * env) Map.map,
	     outerEnv : env option       (* enclosing module *)
           }

    fun freshEnv outerEnv = Env {
           tyEnv = Map.empty,
	   varEnv = Map.empty,
	   bomEnv = emptyBOMEnv, 
	   modEnv = Map.empty,
	   sigEnv = Map.empty,
	   outerEnv = outerEnv
         }

    fun empty outerEnv = Env {
           tyEnv = Map.empty,
	   varEnv = Map.empty,
	   bomEnv = emptyBOMEnv, 
	   modEnv = Map.empty,
	   sigEnv = Map.empty,
	   outerEnv = outerEnv
         }

    fun fromList ls = List.foldl Map.insert' Map.empty ls

    fun insertVal (Env{tyEnv, varEnv, bomEnv, modEnv, sigEnv, outerEnv}, id, x) = 
	Env{tyEnv=tyEnv, varEnv=Map.insert(varEnv, id, x), bomEnv=bomEnv, modEnv=modEnv, sigEnv=sigEnv, outerEnv=outerEnv}
    fun insertMod (Env{tyEnv, varEnv, bomEnv, modEnv, sigEnv, outerEnv}, id, x) = 
	Env{tyEnv=tyEnv, varEnv=varEnv, bomEnv=bomEnv, modEnv=Map.insert(modEnv, id, x), sigEnv=sigEnv, outerEnv=outerEnv}
    fun insertTy (Env{tyEnv, varEnv, bomEnv, modEnv, sigEnv, outerEnv}, id, x) = 
	Env{tyEnv=Map.insert(tyEnv, id, x), varEnv=varEnv, bomEnv=bomEnv, modEnv=modEnv, sigEnv=sigEnv, outerEnv=outerEnv}
    fun insertSig (Env{tyEnv, varEnv, bomEnv, modEnv, sigEnv, outerEnv}, id, x) = 
	Env{tyEnv=tyEnv, varEnv=varEnv, bomEnv=bomEnv, modEnv=modEnv, sigEnv=Map.insert(sigEnv, id, x), outerEnv=outerEnv}
    val insertDataTy = insertTy

  (* BOM environment operations *)
    local 
	fun insertVar (BOMEnv {varEnv}, id, x) =
	        BOMEnv {varEnv=Map.insert(varEnv, id, x)}
    in
    fun insertBOMVar (Env{tyEnv, varEnv, bomEnv, modEnv, sigEnv, outerEnv}, id, x) = 
	    Env{tyEnv=tyEnv, varEnv=varEnv, bomEnv=insertVar(bomEnv, id, x), modEnv=modEnv, sigEnv=sigEnv, outerEnv=outerEnv}
    end

    (* lookup a variable in the scope of the current module *)
    fun findInEnv (Env (fields as {outerEnv, ...}), select, x) = (case Map.find(select fields, x)
        of NONE => 
	   (* x is not bound in this module, so check the enclosing module *)
	   (case outerEnv
	     of NONE => NONE
	      | SOME env => findInEnv(env, select, x))
	 (* found a value *)
	 | SOME v => SOME v)	      

    fun findTy (env, tv) = findInEnv (env, #tyEnv, tv)
    fun findVar (env, v) = findInEnv (env, #varEnv, v)
    fun findMod (env, v) = findInEnv (env, #modEnv, v)
    fun findSig (env, v) = findInEnv (env, #sigEnv, v)

    fun findBOMVar (Env{bomEnv=BOMEnv {varEnv, ...}, outerEnv, ...}, x) = (case Map.find(varEnv, x)
        of NONE => 
	   (* x is not bound in this module, so check the enclosing module *)
	   (case outerEnv
	     of NONE => NONE
	      | SOME env => findBOMVar(env, x))
	 (* found a value *)
	 | SOME v => SOME v)

  (* constrains env2 to contain only those keys that are also in env1 *)
    fun intersect (env1, env2) = Map.intersectWith (fn (x1, x2) => x2) (env1, env2)

  end
