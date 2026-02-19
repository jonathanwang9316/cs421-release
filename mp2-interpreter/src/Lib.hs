module Lib where
import Data.HashMap.Strict as H (HashMap, empty, fromList, insert, lookup, union)
import System.Win32 (COORD(yPos))
import Language.Haskell.TH (safe)


--- Data Types
--- ----------

--- ### Environments and Results

type Env  = H.HashMap String Val
type PEnv = H.HashMap String Stmt

type Result = (String, PEnv, Env)

--- ### Values

data Val = IntVal Int
         | BoolVal Bool
         | CloVal [String] Exp Env
         | ExnVal String
    deriving (Eq)

instance Show Val where
    show (IntVal i) = show i
    show (BoolVal i) = show i
    show (CloVal xs body env) = "<" ++ show xs   ++ ", "
                                    ++ show body ++ ", "
                                    ++ show env  ++ ">"
    show (ExnVal s) = "exn: " ++ s

--- ### Expressions

data Exp = IntExp Int
         | BoolExp Bool
         | FunExp [String] Exp
         | LetExp [(String,Exp)] Exp
         | AppExp Exp [Exp]
         | IfExp Exp Exp Exp
         | IntOpExp String Exp Exp
         | BoolOpExp String Exp Exp
         | CompOpExp String Exp Exp
         | VarExp String
    deriving (Show, Eq)

--- ### Statements

data Stmt = SetStmt String Exp
          | PrintStmt Exp
          | QuitStmt
          | IfStmt Exp Stmt Stmt
          | ProcedureStmt String [String] Stmt
          | CallStmt String [Exp]
          | SeqStmt [Stmt]
    deriving (Show, Eq)

--- Primitive Functions
--- -------------------

intOps :: H.HashMap String (Int -> Int -> Int)
intOps = H.fromList [ ("+", (+))
                    , ("-", (-))
                    , ("*", (*))
                    , ("/", (div))
                    ]

boolOps :: H.HashMap String (Bool -> Bool -> Bool)
boolOps = H.fromList [ ("and", (&&))
                     , ("or", (||))
                     ]

compOps :: H.HashMap String (Int -> Int -> Bool)
compOps = H.fromList [ ("<", (<))
                     , (">", (>))
                     , ("<=", (<=))
                     , (">=", (>=))
                     , ("/=", (/=))
                     , ("==", (==))
                     ]

--- Problems
--- ========

--- Lifting Functions
--- -----------------

liftIntOp :: (Int -> Int -> Int) -> Val -> Val -> Val
liftIntOp op (IntVal x) (IntVal y) = IntVal $ op x y
liftIntOp _ _ _ = ExnVal "Cannot lift"

liftBoolOp :: (Bool -> Bool -> Bool) -> Val -> Val -> Val
liftBoolOp op (BoolVal x) (BoolVal y) = BoolVal $ op x y
liftBoolOp _ _ _ = ExnVal "Cannot lift"

liftCompOp :: (Int -> Int -> Bool) -> Val -> Val -> Val
liftCompOp op (IntVal x) (IntVal y) = BoolVal $ op x y
liftCompOp _ _ _ = ExnVal "Cannot lift"

--- Eval
--- ----

eval :: Exp -> Env -> Val

--- ### Constants

eval (IntExp i)  _ = IntVal i
eval (BoolExp i) _ = BoolVal i

--- ### Variables

eval (VarExp s) env =
    case H.lookup s env of
        Just val -> val
        Nothing -> ExnVal "No match in env"

--- ### Arithmetic

eval (IntOpExp op e1 e2) env = 
    let v1 = eval e1 env
        v2 = eval e2 env
    in case H.lookup op intOps of
        Just f -> if op == "/" && v2 == IntVal 0
                  then ExnVal "Division by 0"
                  else liftIntOp f v1 v2
        Nothing -> ExnVal "No matching operator"

--- ### Boolean and Comparison Operators

eval (BoolOpExp op e1 e2) env = 
    let v1 = eval e1 env
        v2 = eval e2 env
    in case H.lookup op boolOps of
        Just f -> liftBoolOp f v1 v2
        Nothing -> ExnVal "No matching operator"

eval (CompOpExp op e1 e2) env = 
    let v1 = eval e1 env
        v2 = eval e2 env
    in case H.lookup op compOps of
        Just f -> liftCompOp f v1 v2
        Nothing -> ExnVal "No matching operator"

--- ### If Expressions

eval (IfExp e1 e2 e3) env =
    let v2 = eval e2 env
        v3 = eval e3 env
    in case eval e1 env of
        BoolVal v1 -> if v1 then v2 else v3
        _ -> ExnVal "Condition is not a Bool"

--- ### Functions and Function Application

eval (FunExp params body) env = CloVal params body env

eval (AppExp e1 args) env = 
    case eval e1 env of
        CloVal params body env2 -> 
            let retVals = map (\e -> eval e env) args
                pairs = zip params retVals
                newEnv = H.union (H.fromList pairs) env2
                vf = eval body newEnv
            in vf
        _ -> ExnVal "Apply to non-closure"

--- ### Let Expressions

eval (LetExp pairs body) env = 
    let (params, args) = unzip pairs
        retVals = map (\e -> eval e env) args
        pairs2 = zip params retVals
        newEnv = H.union (H.fromList pairs2) env
        vf = eval body newEnv
    in vf

--- Statements
--- ----------

-- Statement Execution
-- -------------------

exec :: Stmt -> PEnv -> Env -> Result
exec (PrintStmt e) penv env = (val, penv, env)
    where val = show $ eval e env

--- ### Set Statements

exec (SetStmt var e) penv env = ("", penv, newEnv)
    where newEnv = H.union (H.fromList [(var, eval e env)]) env

--- ### Sequencing

exec (SeqStmt e) penv env = helper e penv env
    where
        helper [] penv2 env2 = ("", penv2, env2)
        helper (x:xs) penv2 env2 = (x_print ++ xs_print, penv4, env4)
            where
                (x_print, penv3, env3) = exec x penv2 env2
                (xs_print, penv4, env4) = helper xs penv3 env3

--- ### If Statements

exec (IfStmt e1 s1 s2) penv env = 
    let p1 = exec s1 penv env
        p2 = exec s2 penv env
    in case eval e1 env of
        BoolVal v -> if v then p1 else p2
        _ -> ("exn: Condition is not a Bool", penv, env)

--- ### Procedure and Call Statements

exec p@(ProcedureStmt name args body) penv env = ("", newPenv, env)
    where newPenv = H.union (H.fromList [(name, p)]) penv

exec (CallStmt name args) penv env =
    case H.lookup name penv of
        Just (ProcedureStmt f ps body) -> (pf, newPenv, newEnv)
            where 
                retVals = map (\e -> eval e env) args
                pairs = zip ps retVals
                env2 = H.union (H.fromList pairs) env
                (pf, newPenv, newEnv) = exec body penv env2
        Nothing -> ("Procedure " ++ name ++ " undefined", penv, env)