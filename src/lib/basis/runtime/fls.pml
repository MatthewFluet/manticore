(* fls.pml
 *
 * COPYRIGHT (c) 2009 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *
 * Implicit local memory for fibers. Each running fiber is associated with at exactly one
 * FLS object. FLS supports a few operations, which are explained below.
 *
 *   - interfacing with the host vproc
 *     Each vproc is assigned one FLS object at a time. Any fiber running on the vproc is
 *     associated with this FLS. The @get field returns the FLS assigned to the host vproc, 
 *     and the @set operation assigns a given FLS to the host vproc.
 *
 *   - pinning
 *     The @pin-to operation marks a fiber as pinned to a particular vproc. Once pinned, a 
 *     fiber should not migrate. The @pin-info operation accesses the pinning information,
 *     which is a valid vproc id if the FLS is pinned. The @pin-to operation marks a given
 *     FLS as pinned to a given vproc id.
 *
 *   - implicit-threading environment (ITE)
 *     This environment is an extension to FLS that supports threads generated by an 
 *     implicit-threading construct. One can access this field via @get-ite or @find-ite,
 *     and can initialize this field via @set-ite.
 * 
 * The representation of FLS consists of the following fields.
 *
 *   - vproc id
 *     If this number is a valid vproc id, e.g., in the range [0, ..., p-1], then
 *     the associated fiber is pinned to that vproc. Otherwise the associated fiber
 *     can migrate to other vprocs.
 *
 *   - implicit-threading environment
 *     A nonempty value in this field indicates that the fiber represents an implicit
 *     thread.
 *     
 *)

structure FLS (* :
  sig

    _prim(

    (* environment of an implicit thread; see ../implicit-threading/implicit-thread.pml *)
      typedef ite = [
	  PrimStk.stk,                  (* work-group stack *)
	  Option.option                 (* current cancelable *)
	];

    (* fiber-local storage *)
      typedef fls = [
	  int,				(* vproc id *)
	  Option.option			(* optional implicit-thread environment (ITE) *)
	];

    (* create fls *)
      define @new (x : unit / exh : exh) : fls;
    (* create a new FLS pinned to the given vproc *)
      define inline @new-pinned (vprocId : int /) : fls;
    (* set the fls on the host vproc *)
      define inline @set (fls : fls / exh : exh) : ();
    (* get the fls from the host vproc *)
      define inline @get () : fls;

    (* return the pinning information associated with the given FLS *)
      define @pin-info (fls : fls / exh : exh) : int =
    (* pin the current fiber to the host vproc *)
      define @pin-to (fls : fls, vprocId : int / exh : exh) : fls;

    (* find the ITE (if it exists) *)
      define @get-ite (/ exh : exh) : ite;
      define @find-ite (/ exh : exh) : Option.option;
    (* set the ITE *)
      define @set-ite (ite : ite / exh : exh) : ();

    )

  end *) = struct

#define VPROC_OFF              0
#define ITE_OFF                1

    _primcode (

    (* environment of an implicit thread *)
      typedef ite = [
	  PrimStk.stk,		(* work-group stack *)
	  Option.option		(* current cancelable *)
	];

      (* fiber-local storage *)
      typedef fls = [
(* FIXME: why not just use the vproc value here (with nil for no pinning? *)
	  int,			(* if this value is a valid vproc id, the thread is pinned to that vproc *)
(* FIXME: using an option type here adds an unnecessary level of indirection *)
	  Option.option		(* optional implicit-thread environment (ITE) *)
	];

      define @alloc (vprocId : int, ite : Option.option / exh : exh) : fls =
	   let fls : fls = alloc(vprocId, ite)
	   return(fls)
	 ;

    (* create fls *)
      define inline @new (x : unit / exh : exh) : fls =
	  let fls : fls = alloc(~1, Option.NONE)
	  return (fls)
	;

    (* create a new FLS pinned to the given vproc *)
      define inline @new-pinned (vprocId : int /) : fls =
	  let fls : fls = alloc(vprocId, Option.NONE)
	  return (fls)
	;

    (* set the fls on the host vproc *)
      define inline @set (fls : fls) : () =
	  do assert (NotEqual(fls, nil))
	  do vpstore (CURRENT_FG, host_vproc, fls)
	  return ()
	;

      define inline @set-in-atomic (self : vproc, fls : fls) : () =
	  do assert (NotEqual(fls, nil))
	  do vpstore (CURRENT_FG, self, fls)
	  return ()
	;

    (* get the fls from the host vproc *)
      define inline @get () : fls =
	  let fls : fls = vpload (CURRENT_FG, host_vproc)
	  do assert(NotEqual(fls, nil))
	  return(fls)
	;

      define inline @get-in-atomic (self : vproc) : fls =
	  let fls : fls = vpload (CURRENT_FG, self)
	  do assert(NotEqual(fls, nil))
	  return(fls)
	;

    (* return the pinning information associated with the given FLS *)
      define inline @pin-info (fls : fls / exh : exh) : int =
	  return(SELECT(VPROC_OFF, fls))
	;

    (* set the fls as pinned to the given vproc *)
      define inline @pin-to (fls : fls, vprocId : int / exh : exh) : fls =
	  let fls : fls = alloc(vprocId, SELECT(ITE_OFF, fls))
	  return(fls)
	;

    (* find the ITE environment *)

      define @find-ite (/ exh : exh) : Option.option =
	  let fls : fls = @get()
	  return (SELECT(ITE_OFF, fls))
	;

      define @get-ite (/ exh : exh) : ite =
	  let fls : fls = @get()
	  case SELECT(ITE_OFF, fls)
	   of Option.NONE =>
	      let e : exn = Fail(@"FLS.ite: nonexistant implicit threading environment")
	      throw exh(e)
	    | Option.SOME(ite : ite) =>
	      return(ite)
	  end
	;

    (* set the ITE *)
      define @set-ite (ite : ite / exh : exh) : () =
	  let fls : fls = @get()
	  let vProcId : int = @pin-info(fls / exh)
	  let fls : fls = @alloc(vProcId, Option.SOME(ite) / exh)
	  do @set(fls)  
	  return()
	;

    )

  end
