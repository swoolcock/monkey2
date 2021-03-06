
Namespace mx2

Const VALUE_LVALUE:=1
Const VALUE_ASSIGNABLE:=2

Class Value Extends SNode

	Field type:Type
	Field flags:Int
	
	Method ToString:String() Override
		Return "????? VALUE ????? "+String.FromCString( typeName() )
	End
	
	Method ToValue:Value( instance:Value ) Override
		Return Self
	End
	
	Property IsLValue:Bool()
		Return (flags & VALUE_LVALUE)<>0
	End
	
	Property IsAssignable:Bool()
		Return (flags & VALUE_ASSIGNABLE)<>0
	End
	
	Property HasSideEffects:Bool() Virtual
		Return False
	End
	
	Method RemoveSideEffects:Value( block:Block ) Virtual
		Return Self
	End

	Method ToRValue:Value() Virtual
		Return Self
	End
	
	Method UpCast:Value( type:Type ) Virtual
		Local rvalue:=ToRValue()
		Local d:=rvalue.type.DistanceToType( type )
		If d<0 Throw New UpCastEx( rvalue,type )
		If d>0 Return New UpCastValue( type,rvalue )
		Return rvalue
	End
	
	Method FindValue:Value( ident:String ) Virtual
		Local rvalue:=ToRValue()
		Local node:=rvalue.type.FindNode( ident )
		If node Return node.ToValue( rvalue )
		Return Null
	End

	Method Invoke:Value( args:Value[] ) Virtual
		Local rvalue:=ToRValue()
		Return rvalue.type.Invoke( args,rvalue )
	End
	
	Method Index:Value( args:Value[] ) Virtual
		Local rvalue:=ToRValue()
		Return rvalue.type.Index( args,rvalue )
	End
	
	Method GenInstance:Value( types:Type[] ) Virtual
		Throw New SemantEx( "Value '"+ToString()+"' is Not generic" )
	End
	
	Method Assign:Stmt( pnode:PNode,op:String,value:Value,block:Block ) Virtual
		If Not IsAssignable SemantError( "Value.Assign()" )
		
		Local rtype:=BalanceAssignTypes( op,type,value.type )
		Return New AssignStmt( pnode,op,Self,value.UpCast( rtype ) )
		
'		ValidateAssignOp( op,type )
'		value=value.UpCast( type )
'		Return New AssignStmt( pnode,op,Self,value )

	End
	
	Method CheckAccess( tscope:Scope ) Virtual
	End
	
	Function CheckAccess( decl:Decl,scope:Scope,tscope:Scope )
	
		If decl.IsPublic Return
		
		Local cscope:=Cast<ClassScope>( scope )
		If cscope
		
			If scope.FindFile()=tscope.FindFile() Return

			If decl.IsInternal
				If scope.FindFile().fdecl.module=tscope.FindFile().fdecl.module Return

				Throw New SemantEx( "Internal member '"+decl.ident+"' cannot be accessed from different module" )
			Endif

			Local ctype:=cscope.ctype
			Local ctype2:=tscope.FindClass()
			
			If decl.IsPrivate
			
				If ctype=ctype2 Return
				
				Throw New SemantEx( "Private member '"+decl.ident+"' cannot be accessed from here" )
				
			Else If decl.IsProtected
			
				While ctype2
					If ctype=ctype2 Return
					ctype2=ctype2.superType
				Wend
				
				Throw New SemantEx( "Protected member '"+decl.ident+"' cannot be accessed from here" )
			Endif

		Endif
		
	End
	
	#rem
	Function IsValidAssignOp:Bool( op:String,type:Type )

		If op="=" Return True

		Local ptype:=TCast<PrimType>( type )
		If ptype
			Select op
			Case "+=" Return ptype=Type.StringType Or ptype.IsNumeric
			Case "*=","/=","mod=","-=" Return ptype.IsNumeric
			Case "&=","|=","~=" Return ptype.IsIntegral
			Case "shl=","shr=" Return ptype.IsIntegral
			Case "and","or" Return ptype=Type.BoolType
			End
			Return False
		Endif
		
		If TCast<EnumType>( type ) Return op="&=" Or op="|=" Or op="~="
		
		If TCast<PointerType>( type ) Return op="+=" Or op="-="
		
		If TCast<FuncType>( type ) Return op="+=" Or op="-="
		
		Return False
	End
	
	Function ValidateAssignOp( op:String,type:Type )
		If Not IsValidAssignOp( op,type ) Throw New SemantEx( "Assignment operator '"+op+"' cannot be used with type '"+type.ToString()+"'" )
	End
	#end
	
End

Class TypeValue Extends Value

	Field ttype:Type
	
	Method New( ttype:Type )
		Self.type=Type.VoidType
		Self.ttype=ttype
	End
	
	Method ToString:String() Override
		Return "<"+ttype.ToString()+">"
	End
	
	Method FindValue:Value( ident:String ) Override
		Local node:=ttype.FindNode( ident )
		If node Return node.ToValue( Null )
		Return Null
	End
End

Class UpCastValue Extends Value

	Field value:Value

	Method New( type:Type,value:Value )
		Self.type=type
		Self.value=value
	End
	
	Method ToString:String() Override
		Return value.ToString()
	End

	Property HasSideEffects:Bool() Override
		Return value.HasSideEffects
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		If Not HasSideEffects Return Self
		Return New UpCastValue( type,value.RemoveSideEffects( block ) )
	End
	
	Method CheckAccess( tscope:Scope ) Override
		value.CheckAccess( tscope )
	End
	
End

Class ExplicitCastValue Extends Value

	Field value:Value
	
	Method New( type:Type,value:Value )
		Self.type=type
		Self.value=value
	End
	
	Method ToString:String() Override
		Return "Cast<"+type.ToString()+">("+value.ToString()+")"
	End

	Property HasSideEffects:Bool() Override
		Return value.HasSideEffects
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		If Not HasSideEffects Return Self
		Return New ExplicitCastValue( type,value.RemoveSideEffects( block ) )
	End
	
End

Class SelfValue Extends Value

	Field ctype:ClassType
	
	Method New( ctype:ClassType )
		Self.type=ctype
		Self.ctype=ctype
		
		If ctype.IsStruct flags|=VALUE_LVALUE|VALUE_ASSIGNABLE
	End
	
	Method ToString:String() Override
		Return "Self"
	End
	
End

Class SuperValue Extends Value

	Field ctype:ClassType

	Method New( ctype:ClassType )
		Self.type=ctype
		Self.ctype=ctype
	End
	
	Method ToString:String() Override
		Return "Super"
	End

End

Class LiteralValue Extends Value

	Field value:String
	
	Method New( type:Type,value:String )
		Self.type=type
		Self.value=value
	End
	
	Method ToString:String() Override
		If value Return value
		Return "Null"
	End
	
	Method UpCast:Value( type:Type ) Override
	
		Local d:=Self.type.DistanceToType( type )
		If d<0 Throw New UpCastEx( Self,type )
		If d=0 Return Self
		
		'upcast to...
		Local ptype:=TCast<PrimType>( type )
		If Not ptype Return New UpCastValue( type,Self )
'		If Not ptype SemantError( "LiteralValue.UpCast()" )
		
		Local ptype2:=TCast<PrimType>( Self.type )
		If Not ptype2 Return New UpCastValue( type,Self )
'		If Not ptype2 SemantError( "LiteralValue.UpCast()" )
		
		Local result:=""
		
		If ptype=Type.BoolType
			result="false"
			If ptype2.IsIntegral
				If ULong( value ) result="true"
			Else If ptype2.IsReal
				If Double( value ) result="true"
			Else If ptype2=Type.StringType
				If value result="true"
			Else
				SemantError( "LiteralValue.UpCast()" )
			Endif
		Else If ptype.IsIntegral
			result="0"
			If ptype2=Type.BoolType
				If value="true" result="1"
			Else If ptype2.IsNumeric Or ptype2=Type.StringType
				result=String( ULong( value ) )
			Else
				SemantError( "LiteralValue.UpCast()" )
			Endif
		Else If ptype.IsReal
			result="0.0"
			If ptype2=Type.BoolType
				If value="true" result="1.0"
			Else If ptype2.IsNumeric Or ptype2=Type.StringType
				result=String( Double( value ) )
			Else
				SemantError( "LiteralValue.UpCast()" )
			Endif
		Else If ptype=Type.StringType
			result=value
		Else
			SemantError( "LiteralValue.UpCast()" )
		End
		
		Return New LiteralValue( type,result )
	End
	
	Property HasSideEffects:Bool() Override
		Return type.Dealias=Type.StringType
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		If HasSideEffects Return block.AllocLocal( Self )
		Return Self
	End
	
	Function BoolValue:LiteralValue( value:Bool )
		If value Return New LiteralValue( Type.BoolType,"true" )
		Return New LiteralValue( Type.BoolType,"false" )
	End

	Function IntValue:LiteralValue( value:Int )
		Return New LiteralValue( Type.IntType,String( value ) )
	End	
End

Class NullValue Extends Value

	Method New()
		Self.type=Type.NullType
	End
	
	Method ToString:String() Override
		Return "Null"
	End
	
	Method ToRValue:Value() Override
		Throw New SemantEx( "'Null' has no type!" )
		Return Null
	End
		
	Method UpCast:Value( type:Type ) Override
		Return New LiteralValue( type,"" )
	End
	
End

Class InvokeValue Extends Value

	Field ftype:FuncType
	Field value:Value
	Field args:Value[]
	
	Method New( value:Value,args:Value[] )
		Self.ftype=TCast<FuncType>( value.type )
		Self.type=ftype.retType
		Self.value=value
		Self.args=args
	End
	
	Method ToString:String() Override
		Return value.ToString()+"("+Join( args )+")!"
	End
	
	Property HasSideEffects:Bool() Override
		Return True
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		Return block.AllocLocal( Self )
	End
	
	Method CheckAccess( scope:Scope ) Override
		value.CheckAccess( scope )
		For Local arg:=Eachin args
			arg.CheckAccess( scope )
		Next
	End
	
End

Class InvokeNewValue Extends Value

	Field ctype:ClassType
	Field args:Value[]
	
	Method New( ctype:ClassType,args:Value[] )
		Self.type=Type.VoidType
		Self.ctype=ctype
		Self.args=args
	End
	
	Method ToString:String() Override
		Return "New("+Join( args )+")"
	End
	
End

Class NewObjectValue Extends Value

	Field ctype:ClassType
	Field ctor:FuncValue
	Field args:Value[]
	
	Method New( ctype:ClassType,ctor:FuncValue,args:Value[] )
		Self.type=ctype
		Self.ctype=ctype
		self.ctor=ctor
		Self.args=args
	End
	
	Method ToString:String() Override
		Return "New "+ctype.ToString()+"("+Join( args )+")"
	End

	Property HasSideEffects:Bool() Override
		Return True
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		Return block.AllocLocal( Self )
	End
	
End

Class NewArrayValue Extends Value

	Field atype:ArrayType
	Field sizes:Value[]
	Field inits:Value[]
	
	Method New( atype:ArrayType,sizes:Value[],inits:Value[] )
		Self.type=atype
		Self.atype=atype
		Self.sizes=sizes
		Self.inits=inits
	End
	
	Method ToString:String() Override
		If inits Return atype.ToString()+"("+Join( inits )+")"
		Return "New "+atype.elemType.ToString()+"["+Join( sizes )+"]"
	End
	
	Property HasSideEffects:Bool() Override
		Return True
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		Return block.AllocLocal( Self )
	End
	
End

Class ArrayIndexValue Extends Value

	Field atype:ArrayType
	Field value:Value
	Field args:Value[]
	
	Method New( atype:ArrayType,value:Value,args:Value[] )
		Self.type=atype.elemType
		Self.atype=atype
		Self.value=value
		Self.args=args
		
		flags|=VALUE_LVALUE|VALUE_ASSIGNABLE
	End
	
	Method ToString:String() Override
		Return value.ToString()+"["+Join( args )+"]"
	End
	
	Property HasSideEffects:Bool() Override
		If value.HasSideEffects Return True
		For Local arg:=Eachin args
			If arg.HasSideEffects Return True
		Next
		Return False
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		If Not HasSideEffects Return Self
		Local value:=Self.value.RemoveSideEffects( block )
		Local args:=Self.args.Slice( 0 )
		For Local i:=0 Until args.Length
			args[i]=args[i].RemoveSideEffects( block )
		Next
		Return New ArrayIndexValue( atype,value,args )
	End

End

Class StringIndexValue Extends Value

	Field value:Value
	Field index:Value
	
	Method New( value:Value,index:Value )
		Self.type=Type.IntType
		Self.value=value
		Self.index=index
	End
	
	Method ToString:String() Override
		Return value.ToString()+"["+index.ToString()+"]"
	End
	
	Property HasSideEffects:Bool() Override
		Return value.HasSideEffects Or index.HasSideEffects
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		If Not HasSideEffects Return Self
		Local value:=Self.value.RemoveSideEffects( block )
		Local index:=Self.index.RemoveSideEffects( block )
		Return New StringIndexValue( value,index )
	End
	
End

Class PointerIndexValue Extends Value

	Field value:Value
	Field index:Value
	
	Method New( elemType:Type,value:Value,index:Value )
		Self.type=elemType
		Self.value=value
		Self.index=index
		
		flags|=VALUE_LVALUE|VALUE_ASSIGNABLE
	End
	
	Method ToString:String() Override
		Return value.ToString()+"["+index.ToString()+"]"
	End
	
	Property HasSideEffects:Bool() Override
		Return value.HasSideEffects Or index.HasSideEffects
	End
	
	Method RemoveSideEffects:Value( block:Block ) Override
		If Not HasSideEffects Return Self
		Local value:=Self.value.RemoveSideEffects( block )
		Local index:=Self.index.RemoveSideEffects( block )
		Return New StringIndexValue( value,index )
	End

End

Class UnaryopValue Extends Value

	Field op:String
	Field value:Value
	
	Method New( type:Type,op:String,value:Value )
		Self.type=type
		Self.op=op
		Self.value=value
	End
	
	Method ToString:String() Override
		Return op+value.ToString()
	End
	
End

Class BinaryopValue Extends Value

	Field op:String
	Field lhs:Value
	Field rhs:Value
	
	Method New( type:Type,op:String,lhs:Value,rhs:Value )
		Self.type=type
		Self.op=op
		Self.lhs=lhs
		Self.rhs=rhs
	End
	
	Method ToString:String() Override
		Return "("+lhs.ToString()+op+rhs.ToString()+")"
	End
	
End

Class IfThenElseValue Extends Value

	Field value:Value
	Field thenValue:Value
	Field elseValue:Value
	
	Method New( type:Type,value:Value,thenValue:Value,elseValue:Value )
		Self.type=type
		Self.value=value
		Self.thenValue=thenValue
		Self.elseValue=elseValue
	End

End

Class PointerValue Extends Value

	Field value:Value

	Method New( value:Value )
		type=New PointerType( value.type )
		Self.value=value
	End
	
	Method ToString:String() Override
		Return value.ToString()+" Ptr"
	End

End
