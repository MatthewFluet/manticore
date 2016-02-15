(* load-file.sml
 *
 * COPYRIGHT (c) 2008 The Manticore Project (http://manticore.cs.uchicago.edu)
 * All rights reserved.
 *)

structure LoadFile : sig

    datatype event_attr
      = ATTR_SRC			(* this event is the source of a dependent event
					 * and has a new-id argument.
					 *)
      | ATTR_PML			(* this event is only generated by PML/BOM code *)
      | ATTR_RT				(* this event is only generated by C code *)
      | ATTR_GHC                        (* This event overlaps with an already defined GHC event*)

    type color = int * int * int
	    
    datatype event = EVT of {
	name : string,			(* event name *)
	id : int,			(* unique integer ID *)
	args : EventSig.arg_desc list,	(* arguments *)
	sign : string,			(* signature *)
	attrs : event_attr list,	(* attributes *)
	desc : string,	         	(* description *)
	format : string option,         (* formatted description*)
	color : (string * color) option
      }

    type log_file_desc = {
	date : string,
	version : {major : int, minor : int, patch : int},
	events : event list
      }

    val loadFile : string -> log_file_desc

    val hasAttr : event_attr -> event -> bool

  (* helper functions *)
    val filterEvents : (event -> bool) -> log_file_desc -> log_file_desc
    val applyToEvents : (event -> unit) -> log_file_desc -> unit
    val foldEvents : ((event * 'a) -> 'a) -> 'a -> log_file_desc -> 'a

    structure ColorMap : ORD_MAP where type Key.ord_key = string
    val colors : color ColorMap.map
									
  end = struct

    structure J = JSON

    datatype event_attr
      = ATTR_SRC			(* this event is the source of a dependent event
					 * and has a new-id argument.
					 *)
      | ATTR_PML			(* this event is only generated by PML/BOM code *)
      | ATTR_RT				(* this event is only generated by C code *)
      | ATTR_GHC                        (* This event overlaps with an already defined GHC event*)

    type color = int * int * int
				 
    datatype event = EVT of {
	name : string,
	id : int,
	args : EventSig.arg_desc list,
	sign : string,
	attrs : event_attr list,
	desc : string,
	format : string option,
	color : (string * color) option
      }

    type log_file_desc = {
	date : string,
	version : {major : int, minor : int, patch : int},
	events : event list
      }
			     
    structure ColorMap = RedBlackMapFn(struct
					type ord_key = string
					val compare = String.compare
					end)
				      
    val colors = List.foldl (fn (kv, m) => ColorMap.insert'(kv, m))
			    ColorMap.empty
			    [
			      ("black", (0x0, 0x0, 0x0)),
			      ("grey", (0x8000, 0x8000, 0x8000)),
			      ("lightGrey", (0xD000, 0xD000, 0xD000)),
			      ("red", (0xFFFF, 0x0, 0x0)),
			      ("green", (0x0, 0xFFFF, 0x0)),
			      ("darkGreen", (0x0, 0x6600, 0x0)),
			      ("blue", (0x0, 0x0, 0xFFFF)),
			      ("cyan", (0x0, 0xFFFF, 0xFFFF)),
			      ("magenta", (0xFFFF, 0x0, 0xFFFF)),
			      ("lightBlue", (0x6600, 0x9900, 0xFF00)),
			      ("darkBlue", ( 0, 0, 0xBB00)),
			      ("purple", ( 0x9900, 0x0000, 0xcc00)),
			      ("darkPurple", ( 0x6600, 0, 0x6600)),
			      ("darkRed", ( 0xcc00, 0x0000, 0x0000)),
			      ("orange", ( 0xE000, 0x7000, 0x0000)),
			      ("profileBackground", ( 0xFFFF, 0xFFFF, 0xFFFF)),
			      ("tickColour", ( 0x3333, 0x3333, 0xFFFF)),
			      ("darkBrown", ( 0x6600, 0, 0)),
			      ("yellow", ( 0xff00, 0xff00, 0x3300)),
			      ("white", ( 0xffff, 0xffff, 0xffff))
			    ]
			    
    fun hasAttr attr (EVT{attrs, ...}) = List.exists (fn a => (attr = a)) attrs

    fun findField (J.OBJECT fields) = let
	  fun find lab = (case List.find (fn (l, v) => (l = lab)) fields
		 of NONE => NONE
		  | SOME(_, v) => SOME v
		(* end case *))
	  in
	    find
	  end
      | findField _ = raise Fail "expected object"

    fun lookupField findFn lab = (case findFn lab
	   of NONE => raise Fail(concat["no definition for field \"", lab, "\""])
	    | SOME v => v
	  (* end case *))

    fun cvtArray cvtFn (J.ARRAY vl) = List.map cvtFn vl
      | cvtArray cvtFn _ = raise Fail "expected array"

  (* fold a function over a JSON array value *)
    fun foldl cvtFn init (J.ARRAY vl) = List.foldl cvtFn init vl
      | foldl _ _ _ = raise Fail "expected array"

    fun findInt find = let
	  fun get lab = (case find lab of J.INT r => r | _ => raise Fail "expected integer")
	  in
	    get
	  end

    fun findString find = let
	  fun get lab = (case find lab
			  of J.STRING s => s
			    | _ => raise Fail "expected string"
		(* end case *))
	  in
	    get
	  end
      
    fun cvtArg (obj, (loc, ads)) = let
	  val find = findField obj
	  val lookup = lookupField find
	  val name = findString lookup "name"
	  val ty = (case EventSig.tyFromString (findString lookup "ty")
		 of SOME ty => ty
		  | NONE => raise Fail "bogus type"
		(* end case *))
	  val (loc, nextLoc) = (case find "loc"
		 of SOME(J.INT n) => let
		      val loc = Word.fromLargeInt n
		      in
		      (* NOTE: we don't check that loc is properly aligned here;
		       * that is checked later when we compute the signature.
		       *)
			(loc, loc + #sz(EventSig.alignAndSize ty))
		      end
		  | SOME _ => raise Fail "expected integer for \"loc\" field"
		  | NONE => let
		      val {align, sz, ...} = EventSig.alignAndSize ty
		      val loc = EventSig.alignLoc (loc, align)
		      in
			(loc, loc+sz)
		      end
		(* end case *))
	  val desc = findString lookup "desc"
	  val ad = {
		  name = name,
		  ty = ty,
		  loc = loc,
		  desc = desc
		}
	  in
	    (nextLoc, ad::ads)
	  end

    fun cvt obj = let
	  val find = lookupField(findField obj)
	  val version = (case find "version"
		 of J.ARRAY[J.INT v1, J.INT v2, J.INT v3] => {
			major = Int.fromLarge v1,
			minor = Int.fromLarge v2,
			patch = Int.fromLarge v3
		      }
		  | _ => raise Fail "bogus version"
		(* end case *))
	  val nextId = ref 1	(* ID 0 is unused *)
	  fun cvtEvent obj = let
		val find = lookupField (findField obj)
		val name = findString find "name"
		val args = let
		      val (_, args) = foldl cvtArg (EventSig.argStart, []) (find "args")
		      in
			List.rev args
		      end
		val id = !nextId
		val attrs = (case findField obj "attrs"
		       of SOME arr => let
			    fun cvt (J.STRING attr) = (case attr
				   of "src" => ATTR_SRC
				    | "pml" => ATTR_PML
				    | "rt" => ATTR_RT
				    | "ghc" => ATTR_GHC
				    | s => raise Fail(concat[
					  "invalid attribute \"", String.toString s, "\""
					])
				  (* end case *))
			      | cvt _ = raise Fail "attributes must be strings"
			    in
			      cvtArray cvt arr
			    end
			| NONE => []
			    (* end case *))
		val format =
		    case findField obj "format"
		     of NONE => NONE
		      | SOME (J.STRING fmt) => SOME fmt
		      | _ => raise Fail "Expected a string for format"
		val color =
		    case findField obj "color"
		     of NONE => NONE
		      | SOME (J.STRING color) =>
			case ColorMap.find(colors, color)
			 of SOME c => SOME (color, c)
			  | _ => raise Fail(String.concat["Color: ", color, " was specified, but does not exist in the map of known colors"])
		in
		  nextId := id + 1;
		  EVT{
		      name = name, id = id, args = args, attrs = attrs,
		      sign = EventSig.signOf args, desc = findString find "desc", format = format,
		      color = color
		    }
		end
	  in {
	    date = findString find "date",
	    version = version,
	    events = cvtArray cvtEvent (find "events")
	  } end

    fun loadFile file = cvt (JSONParser.parseFile file)

  (* helper functions *)
    fun filterEvents pred {date, version, events} = {
	    date=date, version=version,
	    events = List.filter pred events
	  }
    fun applyToEvents f {date, version, events} = List.app f events
    fun foldEvents f init {date, version, events} = List.foldl f init events

  end
