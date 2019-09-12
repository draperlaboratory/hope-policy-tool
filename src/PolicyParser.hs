{-# OPTIONS_GHC -w #-}
module PolicyParser (polParse) where

  
import PolicyLexer
import AST
import CommonTypes (Options(..))
import CommonFn (dotName)
import ErrorMsg (ErrMsg(..))
import System.FilePath ((</>),(<.>),joinPath)
import System.Directory (doesFileExist)
import Control.Monad (foldM)
import qualified Data.Array as Happy_Data_Array
import qualified Data.Bits as Bits
import Control.Applicative(Applicative(..))
import Control.Monad (ap)

-- parser produced by Happy Version 1.19.8

data HappyAbsSyn 
	= HappyTerminal ((Located Token))
	| HappyErrorToken Int
	| HappyAbsSyn4 (ModuleDecl QSym)
	| HappyAbsSyn5 ([SectDecl QSym])
	| HappyAbsSyn6 (SectDecl QSym)
	| HappyAbsSyn7 ([ImportDecl QSym])
	| HappyAbsSyn8 (ImportDecl QSym)
	| HappyAbsSyn9 ([TypeDecl QSym])
	| HappyAbsSyn10 (TypeDecl QSym)
	| HappyAbsSyn11 (TagDataType)
	| HappyAbsSyn12 (Maybe Int)
	| HappyAbsSyn13 ([TagDecl QSym])
	| HappyAbsSyn14 (TagDecl QSym)
	| HappyAbsSyn15 ([QSym])
	| HappyAbsSyn16 ([GroupDecl [ISA] QSym])
	| HappyAbsSyn17 (GroupDecl [ISA] QSym)
	| HappyAbsSyn18 ([GroupParam QSym])
	| HappyAbsSyn19 (GroupParam QSym)
	| HappyAbsSyn20 (TagSpec)
	| HappyAbsSyn21 ([ISA])
	| HappyAbsSyn22 (ISA)
	| HappyAbsSyn23 ([OpSpec])
	| HappyAbsSyn24 (OpSpec)
	| HappyAbsSyn25 ([PolicyDecl QSym])
	| HappyAbsSyn26 (PolicyDecl QSym)
	| HappyAbsSyn27 (PolicyLocality)
	| HappyAbsSyn28 (PolicyEx QSym)
	| HappyAbsSyn30 ([BoundGroupPat QSym])
	| HappyAbsSyn31 (BoundGroupPat QSym)
	| HappyAbsSyn32 (TagSetPat QSym)
	| HappyAbsSyn33 ([Tag QSym])
	| HappyAbsSyn34 (Tag QSym)
	| HappyAbsSyn36 ([TagField QSym])
	| HappyAbsSyn37 (TagField QSym)
	| HappyAbsSyn38 ([TagEx QSym])
	| HappyAbsSyn39 (TagEx QSym)
	| HappyAbsSyn40 (SrcPos -> Tag QSym -> TagEx QSym)
	| HappyAbsSyn41 (RuleResult QSym)
	| HappyAbsSyn42 ([BoundGroupEx QSym])
	| HappyAbsSyn43 (BoundGroupEx QSym)
	| HappyAbsSyn44 (TagSetEx QSym)
	| HappyAbsSyn45 ([RequireDecl QSym])
	| HappyAbsSyn46 (RequireDecl QSym)
	| HappyAbsSyn47 (InitSet QSym)

{- to allow type-synonyms as our monads (likely
 - with explicitly-specified bind and return)
 - in Haskell98, it seems that with
 - /type M a = .../, then /(HappyReduction M)/
 - is not allowed.  But Happy is a
 - code-generator that can just substitute it.
type HappyReduction m = 
	   Int 
	-> ((Located Token))
	-> HappyState ((Located Token)) (HappyStk HappyAbsSyn -> m HappyAbsSyn)
	-> [HappyState ((Located Token)) (HappyStk HappyAbsSyn -> m HappyAbsSyn)] 
	-> HappyStk HappyAbsSyn 
	-> m HappyAbsSyn
-}

action_0,
 action_1,
 action_2,
 action_3,
 action_4,
 action_5,
 action_6,
 action_7,
 action_8,
 action_9,
 action_10,
 action_11,
 action_12,
 action_13,
 action_14,
 action_15,
 action_16,
 action_17,
 action_18,
 action_19,
 action_20,
 action_21,
 action_22,
 action_23,
 action_24,
 action_25,
 action_26,
 action_27,
 action_28,
 action_29,
 action_30,
 action_31,
 action_32,
 action_33,
 action_34,
 action_35,
 action_36,
 action_37,
 action_38,
 action_39,
 action_40,
 action_41,
 action_42,
 action_43,
 action_44,
 action_45,
 action_46,
 action_47,
 action_48,
 action_49,
 action_50,
 action_51,
 action_52,
 action_53,
 action_54,
 action_55,
 action_56,
 action_57,
 action_58,
 action_59,
 action_60,
 action_61,
 action_62,
 action_63,
 action_64,
 action_65,
 action_66,
 action_67,
 action_68,
 action_69,
 action_70,
 action_71,
 action_72,
 action_73,
 action_74,
 action_75,
 action_76,
 action_77,
 action_78,
 action_79,
 action_80,
 action_81,
 action_82,
 action_83,
 action_84,
 action_85,
 action_86,
 action_87,
 action_88,
 action_89,
 action_90,
 action_91,
 action_92,
 action_93,
 action_94,
 action_95,
 action_96,
 action_97,
 action_98,
 action_99,
 action_100,
 action_101,
 action_102,
 action_103,
 action_104,
 action_105,
 action_106,
 action_107,
 action_108,
 action_109,
 action_110,
 action_111,
 action_112,
 action_113,
 action_114,
 action_115,
 action_116,
 action_117,
 action_118,
 action_119,
 action_120,
 action_121,
 action_122,
 action_123,
 action_124,
 action_125,
 action_126,
 action_127,
 action_128,
 action_129,
 action_130,
 action_131,
 action_132,
 action_133,
 action_134,
 action_135,
 action_136,
 action_137,
 action_138,
 action_139,
 action_140,
 action_141,
 action_142,
 action_143,
 action_144,
 action_145,
 action_146,
 action_147,
 action_148,
 action_149,
 action_150,
 action_151,
 action_152,
 action_153,
 action_154,
 action_155,
 action_156,
 action_157,
 action_158,
 action_159,
 action_160,
 action_161,
 action_162,
 action_163,
 action_164,
 action_165,
 action_166,
 action_167,
 action_168,
 action_169,
 action_170,
 action_171,
 action_172,
 action_173,
 action_174,
 action_175,
 action_176,
 action_177,
 action_178,
 action_179,
 action_180,
 action_181,
 action_182,
 action_183,
 action_184,
 action_185,
 action_186,
 action_187,
 action_188,
 action_189,
 action_190,
 action_191,
 action_192,
 action_193,
 action_194,
 action_195,
 action_196,
 action_197,
 action_198,
 action_199,
 action_200,
 action_201,
 action_202,
 action_203,
 action_204,
 action_205,
 action_206,
 action_207,
 action_208 :: () => Int -> ({-HappyReduction (P) = -}
	   Int 
	-> ((Located Token))
	-> HappyState ((Located Token)) (HappyStk HappyAbsSyn -> (P) HappyAbsSyn)
	-> [HappyState ((Located Token)) (HappyStk HappyAbsSyn -> (P) HappyAbsSyn)] 
	-> HappyStk HappyAbsSyn 
	-> (P) HappyAbsSyn)

happyReduce_1,
 happyReduce_2,
 happyReduce_3,
 happyReduce_4,
 happyReduce_5,
 happyReduce_6,
 happyReduce_7,
 happyReduce_8,
 happyReduce_9,
 happyReduce_10,
 happyReduce_11,
 happyReduce_12,
 happyReduce_13,
 happyReduce_14,
 happyReduce_15,
 happyReduce_16,
 happyReduce_17,
 happyReduce_18,
 happyReduce_19,
 happyReduce_20,
 happyReduce_21,
 happyReduce_22,
 happyReduce_23,
 happyReduce_24,
 happyReduce_25,
 happyReduce_26,
 happyReduce_27,
 happyReduce_28,
 happyReduce_29,
 happyReduce_30,
 happyReduce_31,
 happyReduce_32,
 happyReduce_33,
 happyReduce_34,
 happyReduce_35,
 happyReduce_36,
 happyReduce_37,
 happyReduce_38,
 happyReduce_39,
 happyReduce_40,
 happyReduce_41,
 happyReduce_42,
 happyReduce_43,
 happyReduce_44,
 happyReduce_45,
 happyReduce_46,
 happyReduce_47,
 happyReduce_48,
 happyReduce_49,
 happyReduce_50,
 happyReduce_51,
 happyReduce_52,
 happyReduce_53,
 happyReduce_54,
 happyReduce_55,
 happyReduce_56,
 happyReduce_57,
 happyReduce_58,
 happyReduce_59,
 happyReduce_60,
 happyReduce_61,
 happyReduce_62,
 happyReduce_63,
 happyReduce_64,
 happyReduce_65,
 happyReduce_66,
 happyReduce_67,
 happyReduce_68,
 happyReduce_69,
 happyReduce_70,
 happyReduce_71,
 happyReduce_72,
 happyReduce_73,
 happyReduce_74,
 happyReduce_75,
 happyReduce_76,
 happyReduce_77,
 happyReduce_78,
 happyReduce_79,
 happyReduce_80,
 happyReduce_81,
 happyReduce_82,
 happyReduce_83,
 happyReduce_84,
 happyReduce_85,
 happyReduce_86,
 happyReduce_87,
 happyReduce_88,
 happyReduce_89,
 happyReduce_90,
 happyReduce_91,
 happyReduce_92,
 happyReduce_93,
 happyReduce_94,
 happyReduce_95,
 happyReduce_96,
 happyReduce_97,
 happyReduce_98,
 happyReduce_99,
 happyReduce_100,
 happyReduce_101,
 happyReduce_102,
 happyReduce_103,
 happyReduce_104,
 happyReduce_105,
 happyReduce_106,
 happyReduce_107,
 happyReduce_108,
 happyReduce_109,
 happyReduce_110,
 happyReduce_111,
 happyReduce_112,
 happyReduce_113,
 happyReduce_114,
 happyReduce_115,
 happyReduce_116,
 happyReduce_117,
 happyReduce_118,
 happyReduce_119,
 happyReduce_120,
 happyReduce_121,
 happyReduce_122,
 happyReduce_123,
 happyReduce_124,
 happyReduce_125,
 happyReduce_126,
 happyReduce_127,
 happyReduce_128,
 happyReduce_129,
 happyReduce_130,
 happyReduce_131,
 happyReduce_132,
 happyReduce_133,
 happyReduce_134,
 happyReduce_135,
 happyReduce_136,
 happyReduce_137 :: () => ({-HappyReduction (P) = -}
	   Int 
	-> ((Located Token))
	-> HappyState ((Located Token)) (HappyStk HappyAbsSyn -> (P) HappyAbsSyn)
	-> [HappyState ((Located Token)) (HappyStk HappyAbsSyn -> (P) HappyAbsSyn)] 
	-> HappyStk HappyAbsSyn 
	-> (P) HappyAbsSyn)

happyExpList :: Happy_Data_Array.Array Int Int
happyExpList = Happy_Data_Array.listArray (0,313) ([0,0,0,0,32,0,0,0,0,0,0,0,32,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,3264,520,0,0,0,0,0,0,3264,520,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1024,0,0,0,0,0,0,0,16,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,256,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,256,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,1024,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32768,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,4096,0,0,0,128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,512,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,57344,7,0,0,0,0,0,0,0,0,0,6144,0,0,0,0,0,0,0,0,0,0,32768,0,0,0,0,4096,0,0,0,16,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,1792,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32768,0,0,0,0,0,0,0,0,64,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32768,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8192,0,0,0,0,0,0,0,4096,0,0,0,0,57344,7,0,0,0,0,0,0,57344,7,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,6144,0,0,0,0,0,0,0,6144,0,0,0,0,0,0,0,6144,0,0,32768,32768,0,256,0,12288,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32768,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,30720,4,0,0,0,0,0,32768,32768,0,256,0,12288,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,64,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,32778,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,96,0,4096,0,0,0,0,0,0,0,4096,0,0,0,30721,4,0,0,0,0,0,32768,32768,0,256,0,12288,0,0,32768,32768,0,256,0,12288,0,0,32768,32768,0,256,0,12288,0,0,32768,32768,0,256,0,12288,0,0,32768,32768,0,256,0,12288,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,24576,4,0,0,0,0,0,0,24576,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16384,0,0,0,0,0,128,0,0,0,0,0,128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6144,0,0,0,0,0,0,32768,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,4,63488,65535,10239,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,2,0,0,0,0,0,0,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,32768,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,0,0,0,4096,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,2,24,0,0,0,0,0,32768,0,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,6144,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,63488,65535,10239,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,2,0,0,0,0,0,0,6144,0,0,0,0,0,0,0,8,0,0,0,4096,0,0,0,8,0,0,0,4096,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	])

{-# NOINLINE happyExpListPerState #-}
happyExpListPerState st =
    token_strs_expected
  where token_strs = ["error","%dummy","%start_parseModule","module","sections","section","importSect","importStmt","typeSect","typeDecl","tagDataType","optionalSize","metadataSect","mdDecl","typeList","groupSect","groupDecl","grpParams","grpParam","tagSpec","grpInsts","inst","opspecs","opspec","policySect","policyDecl","locality","policyExp","policyRule","boundGroupPats","boundGroupPat","tagSetPat","tags","tag","tagBody","fields","field","tagExs","tagEx","tagMod","ruleResult","boundGroupExs","boundGroupEx","tagSetEx","requireSect","requireDecl","requireSet","'('","')'","'['","']'","'{'","'}'","'=='","'->'","'='","'^'","'|'","'&'","'+'","'-'","'/'","'%'","'_'","':'","','","'*'","'\\\\/'","'/\\\\'","'module'","'import'","'type'","'data'","'Int'","'metadata'","'group'","'grp'","'RD'","'RS1'","'RS2'","'RS3'","'CSR'","'MEM'","'policy'","'global'","'fail'","'allow'","'with'","'new'","'require'","'init'","'x0'","'x1'","'x2'","'x3'","'x4'","'x5'","'x6'","'x7'","'x8'","'x9'","'x10'","'x11'","'x12'","'x13'","'x14'","'x15'","'x16'","'x17'","'x18'","'x19'","'x20'","'x21'","'x22'","'x23'","'x24'","'x25'","'x26'","'x27'","'x28'","'x29'","'x30'","'x31'","'__NO_CHECKS'","QNAME","INTLIT","STRINGLIT","%eof"]
        bit_start = st * 128
        bit_end = (st + 1) * 128
        read_bit = readArrayBit happyExpList
        bits = map read_bit [bit_start..bit_end - 1]
        bits_indexed = zip bits [0..127]
        token_strs_expected = concatMap f bits_indexed
        f (False, _) = []
        f (True, nr) = [token_strs !! nr]

action_0 (70) = happyShift action_2
action_0 (4) = happyGoto action_3
action_0 _ = happyFail (happyExpListPerState 0)

action_1 (70) = happyShift action_2
action_1 _ = happyFail (happyExpListPerState 1)

action_2 (125) = happyShift action_4
action_2 _ = happyFail (happyExpListPerState 2)

action_3 (128) = happyAccept
action_3 _ = happyFail (happyExpListPerState 3)

action_4 (65) = happyShift action_5
action_4 _ = happyFail (happyExpListPerState 4)

action_5 (71) = happyShift action_8
action_5 (72) = happyShift action_9
action_5 (75) = happyShift action_10
action_5 (76) = happyShift action_11
action_5 (84) = happyShift action_12
action_5 (90) = happyShift action_13
action_5 (5) = happyGoto action_6
action_5 (6) = happyGoto action_7
action_5 _ = happyFail (happyExpListPerState 5)

action_6 (71) = happyShift action_8
action_6 (72) = happyShift action_9
action_6 (75) = happyShift action_10
action_6 (76) = happyShift action_11
action_6 (84) = happyShift action_12
action_6 (90) = happyShift action_13
action_6 (6) = happyGoto action_20
action_6 _ = happyReduce_1

action_7 _ = happyReduce_2

action_8 (65) = happyShift action_19
action_8 _ = happyFail (happyExpListPerState 8)

action_9 (65) = happyShift action_18
action_9 _ = happyFail (happyExpListPerState 9)

action_10 (65) = happyShift action_17
action_10 _ = happyFail (happyExpListPerState 10)

action_11 (65) = happyShift action_16
action_11 _ = happyFail (happyExpListPerState 11)

action_12 (65) = happyShift action_15
action_12 _ = happyFail (happyExpListPerState 12)

action_13 (65) = happyShift action_14
action_13 _ = happyFail (happyExpListPerState 13)

action_14 (91) = happyShift action_39
action_14 (45) = happyGoto action_37
action_14 (46) = happyGoto action_38
action_14 _ = happyFail (happyExpListPerState 14)

action_15 (85) = happyShift action_36
action_15 (25) = happyGoto action_33
action_15 (26) = happyGoto action_34
action_15 (27) = happyGoto action_35
action_15 _ = happyReduce_80

action_16 (77) = happyShift action_32
action_16 (16) = happyGoto action_30
action_16 (17) = happyGoto action_31
action_16 _ = happyFail (happyExpListPerState 16)

action_17 (125) = happyShift action_29
action_17 (13) = happyGoto action_27
action_17 (14) = happyGoto action_28
action_17 _ = happyFail (happyExpListPerState 17)

action_18 (73) = happyShift action_26
action_18 (9) = happyGoto action_24
action_18 (10) = happyGoto action_25
action_18 _ = happyFail (happyExpListPerState 18)

action_19 (125) = happyShift action_23
action_19 (7) = happyGoto action_21
action_19 (8) = happyGoto action_22
action_19 _ = happyFail (happyExpListPerState 19)

action_20 _ = happyReduce_3

action_21 (125) = happyShift action_23
action_21 (8) = happyGoto action_50
action_21 _ = happyReduce_4

action_22 _ = happyReduce_10

action_23 _ = happyReduce_12

action_24 (73) = happyShift action_26
action_24 (10) = happyGoto action_49
action_24 _ = happyReduce_5

action_25 _ = happyReduce_13

action_26 (125) = happyShift action_48
action_26 _ = happyFail (happyExpListPerState 26)

action_27 (66) = happyShift action_47
action_27 _ = happyReduce_6

action_28 _ = happyReduce_19

action_29 (15) = happyGoto action_46
action_29 _ = happyReduce_22

action_30 (77) = happyShift action_32
action_30 (17) = happyGoto action_45
action_30 _ = happyReduce_7

action_31 _ = happyReduce_24

action_32 (125) = happyShift action_44
action_32 _ = happyFail (happyExpListPerState 32)

action_33 (85) = happyShift action_36
action_33 (125) = happyReduce_80
action_33 (26) = happyGoto action_43
action_33 (27) = happyGoto action_35
action_33 _ = happyReduce_8

action_34 _ = happyReduce_77

action_35 (125) = happyShift action_42
action_35 _ = happyFail (happyExpListPerState 35)

action_36 _ = happyReduce_81

action_37 (91) = happyShift action_39
action_37 (46) = happyGoto action_41
action_37 _ = happyReduce_9

action_38 _ = happyReduce_134

action_39 (125) = happyShift action_40
action_39 _ = happyFail (happyExpListPerState 39)

action_40 (52) = happyShift action_57
action_40 (47) = happyGoto action_56
action_40 _ = happyFail (happyExpListPerState 40)

action_41 _ = happyReduce_135

action_42 (56) = happyShift action_55
action_42 _ = happyFail (happyExpListPerState 42)

action_43 _ = happyReduce_78

action_44 (48) = happyShift action_54
action_44 _ = happyFail (happyExpListPerState 44)

action_45 _ = happyReduce_25

action_46 (125) = happyShift action_53
action_46 _ = happyReduce_21

action_47 (125) = happyShift action_29
action_47 (14) = happyGoto action_52
action_47 _ = happyFail (happyExpListPerState 47)

action_48 (56) = happyShift action_51
action_48 _ = happyFail (happyExpListPerState 48)

action_49 _ = happyReduce_14

action_50 _ = happyReduce_11

action_51 (74) = happyShift action_77
action_51 (11) = happyGoto action_76
action_51 _ = happyFail (happyExpListPerState 51)

action_52 _ = happyReduce_20

action_53 _ = happyReduce_23

action_54 (78) = happyShift action_70
action_54 (79) = happyShift action_71
action_54 (80) = happyShift action_72
action_54 (81) = happyShift action_73
action_54 (82) = happyShift action_74
action_54 (83) = happyShift action_75
action_54 (18) = happyGoto action_67
action_54 (19) = happyGoto action_68
action_54 (20) = happyGoto action_69
action_54 _ = happyReduce_27

action_55 (124) = happyShift action_65
action_55 (125) = happyShift action_66
action_55 (28) = happyGoto action_63
action_55 (29) = happyGoto action_64
action_55 _ = happyFail (happyExpListPerState 55)

action_56 _ = happyReduce_136

action_57 (48) = happyShift action_61
action_57 (125) = happyShift action_62
action_57 (33) = happyGoto action_58
action_57 (34) = happyGoto action_59
action_57 (35) = happyGoto action_60
action_57 _ = happyReduce_96

action_58 (53) = happyShift action_89
action_58 (66) = happyShift action_90
action_58 _ = happyFail (happyExpListPerState 58)

action_59 _ = happyReduce_97

action_60 _ = happyReduce_99

action_61 (125) = happyShift action_62
action_61 (35) = happyGoto action_88
action_61 _ = happyFail (happyExpListPerState 61)

action_62 (36) = happyGoto action_87
action_62 _ = happyReduce_102

action_63 (57) = happyShift action_84
action_63 (58) = happyShift action_85
action_63 (59) = happyShift action_86
action_63 _ = happyReduce_79

action_64 _ = happyReduce_82

action_65 _ = happyReduce_86

action_66 (48) = happyShift action_83
action_66 _ = happyReduce_87

action_67 (55) = happyShift action_81
action_67 (66) = happyShift action_82
action_67 _ = happyFail (happyExpListPerState 67)

action_68 _ = happyReduce_28

action_69 (65) = happyShift action_80
action_69 _ = happyFail (happyExpListPerState 69)

action_70 _ = happyReduce_31

action_71 _ = happyReduce_32

action_72 _ = happyReduce_33

action_73 _ = happyReduce_34

action_74 _ = happyReduce_35

action_75 _ = happyReduce_36

action_76 _ = happyReduce_15

action_77 (48) = happyShift action_79
action_77 (12) = happyGoto action_78
action_77 _ = happyReduce_18

action_78 _ = happyReduce_16

action_79 (126) = happyShift action_108
action_79 _ = happyFail (happyExpListPerState 79)

action_80 (125) = happyShift action_107
action_80 _ = happyFail (happyExpListPerState 80)

action_81 (78) = happyShift action_70
action_81 (79) = happyShift action_71
action_81 (80) = happyShift action_72
action_81 (81) = happyShift action_73
action_81 (82) = happyShift action_74
action_81 (83) = happyShift action_75
action_81 (18) = happyGoto action_106
action_81 (19) = happyGoto action_68
action_81 (20) = happyGoto action_69
action_81 _ = happyReduce_27

action_82 (78) = happyShift action_70
action_82 (79) = happyShift action_71
action_82 (80) = happyShift action_72
action_82 (81) = happyShift action_73
action_82 (82) = happyShift action_74
action_82 (83) = happyShift action_75
action_82 (19) = happyGoto action_105
action_82 (20) = happyGoto action_69
action_82 _ = happyFail (happyExpListPerState 82)

action_83 (125) = happyShift action_104
action_83 (30) = happyGoto action_102
action_83 (31) = happyGoto action_103
action_83 _ = happyReduce_89

action_84 (124) = happyShift action_65
action_84 (125) = happyShift action_66
action_84 (28) = happyGoto action_101
action_84 (29) = happyGoto action_64
action_84 _ = happyFail (happyExpListPerState 84)

action_85 (124) = happyShift action_65
action_85 (125) = happyShift action_66
action_85 (28) = happyGoto action_100
action_85 (29) = happyGoto action_64
action_85 _ = happyFail (happyExpListPerState 85)

action_86 (124) = happyShift action_65
action_86 (125) = happyShift action_66
action_86 (28) = happyGoto action_99
action_86 (29) = happyGoto action_64
action_86 _ = happyFail (happyExpListPerState 86)

action_87 (48) = happyShift action_94
action_87 (64) = happyShift action_95
action_87 (89) = happyShift action_96
action_87 (125) = happyShift action_97
action_87 (126) = happyShift action_98
action_87 (37) = happyGoto action_93
action_87 _ = happyReduce_101

action_88 (49) = happyShift action_92
action_88 _ = happyFail (happyExpListPerState 88)

action_89 _ = happyReduce_137

action_90 (48) = happyShift action_61
action_90 (125) = happyShift action_62
action_90 (34) = happyGoto action_91
action_90 (35) = happyGoto action_60
action_90 _ = happyFail (happyExpListPerState 90)

action_91 _ = happyReduce_98

action_92 _ = happyReduce_100

action_93 (60) = happyShift action_116
action_93 (61) = happyShift action_117
action_93 (62) = happyShift action_118
action_93 (63) = happyShift action_119
action_93 (67) = happyShift action_120
action_93 _ = happyReduce_103

action_94 (48) = happyShift action_94
action_94 (64) = happyShift action_95
action_94 (89) = happyShift action_96
action_94 (125) = happyShift action_97
action_94 (126) = happyShift action_98
action_94 (37) = happyGoto action_115
action_94 _ = happyFail (happyExpListPerState 94)

action_95 _ = happyReduce_106

action_96 _ = happyReduce_104

action_97 _ = happyReduce_105

action_98 _ = happyReduce_107

action_99 _ = happyReduce_83

action_100 _ = happyReduce_84

action_101 _ = happyReduce_85

action_102 (55) = happyShift action_113
action_102 (66) = happyShift action_114
action_102 (41) = happyGoto action_112
action_102 _ = happyFail (happyExpListPerState 102)

action_103 _ = happyReduce_90

action_104 (54) = happyShift action_111
action_104 _ = happyFail (happyExpListPerState 104)

action_105 _ = happyReduce_29

action_106 (49) = happyShift action_110
action_106 (66) = happyShift action_82
action_106 _ = happyFail (happyExpListPerState 106)

action_107 _ = happyReduce_30

action_108 (49) = happyShift action_109
action_108 _ = happyFail (happyExpListPerState 108)

action_109 _ = happyReduce_17

action_110 (125) = happyShift action_140
action_110 (21) = happyGoto action_138
action_110 (22) = happyGoto action_139
action_110 _ = happyFail (happyExpListPerState 110)

action_111 (50) = happyShift action_135
action_111 (52) = happyShift action_136
action_111 (64) = happyShift action_137
action_111 (32) = happyGoto action_134
action_111 _ = happyFail (happyExpListPerState 111)

action_112 (49) = happyShift action_133
action_112 _ = happyFail (happyExpListPerState 112)

action_113 (86) = happyShift action_130
action_113 (87) = happyShift action_131
action_113 (125) = happyShift action_132
action_113 (42) = happyGoto action_128
action_113 (43) = happyGoto action_129
action_113 _ = happyReduce_125

action_114 (125) = happyShift action_104
action_114 (31) = happyGoto action_127
action_114 _ = happyFail (happyExpListPerState 114)

action_115 (49) = happyShift action_126
action_115 (60) = happyShift action_116
action_115 (61) = happyShift action_117
action_115 (62) = happyShift action_118
action_115 (63) = happyShift action_119
action_115 (67) = happyShift action_120
action_115 _ = happyFail (happyExpListPerState 115)

action_116 (48) = happyShift action_94
action_116 (64) = happyShift action_95
action_116 (89) = happyShift action_96
action_116 (125) = happyShift action_97
action_116 (126) = happyShift action_98
action_116 (37) = happyGoto action_125
action_116 _ = happyFail (happyExpListPerState 116)

action_117 (48) = happyShift action_94
action_117 (64) = happyShift action_95
action_117 (89) = happyShift action_96
action_117 (125) = happyShift action_97
action_117 (126) = happyShift action_98
action_117 (37) = happyGoto action_124
action_117 _ = happyFail (happyExpListPerState 117)

action_118 (48) = happyShift action_94
action_118 (64) = happyShift action_95
action_118 (89) = happyShift action_96
action_118 (125) = happyShift action_97
action_118 (126) = happyShift action_98
action_118 (37) = happyGoto action_123
action_118 _ = happyFail (happyExpListPerState 118)

action_119 (48) = happyShift action_94
action_119 (64) = happyShift action_95
action_119 (89) = happyShift action_96
action_119 (125) = happyShift action_97
action_119 (126) = happyShift action_98
action_119 (37) = happyGoto action_122
action_119 _ = happyFail (happyExpListPerState 119)

action_120 (48) = happyShift action_94
action_120 (64) = happyShift action_95
action_120 (89) = happyShift action_96
action_120 (125) = happyShift action_97
action_120 (126) = happyShift action_98
action_120 (37) = happyGoto action_121
action_120 _ = happyFail (happyExpListPerState 120)

action_121 _ = happyReduce_111

action_122 _ = happyReduce_113

action_123 _ = happyReduce_112

action_124 (62) = happyShift action_118
action_124 (63) = happyShift action_119
action_124 (67) = happyShift action_120
action_124 _ = happyReduce_110

action_125 (62) = happyShift action_118
action_125 (63) = happyShift action_119
action_125 (67) = happyShift action_120
action_125 _ = happyReduce_109

action_126 _ = happyReduce_108

action_127 _ = happyReduce_91

action_128 (66) = happyShift action_187
action_128 _ = happyReduce_124

action_129 _ = happyReduce_126

action_130 (127) = happyShift action_186
action_130 _ = happyFail (happyExpListPerState 130)

action_131 (88) = happyShift action_185
action_131 _ = happyReduce_122

action_132 (56) = happyShift action_184
action_132 _ = happyFail (happyExpListPerState 132)

action_133 _ = happyReduce_88

action_134 _ = happyReduce_92

action_135 (51) = happyReduce_114
action_135 (60) = happyShift action_182
action_135 (61) = happyShift action_183
action_135 (66) = happyReduce_114
action_135 (38) = happyGoto action_179
action_135 (39) = happyGoto action_180
action_135 (40) = happyGoto action_181
action_135 _ = happyReduce_118

action_136 (48) = happyShift action_61
action_136 (125) = happyShift action_62
action_136 (33) = happyGoto action_178
action_136 (34) = happyGoto action_59
action_136 (35) = happyGoto action_60
action_136 _ = happyReduce_96

action_137 _ = happyReduce_93

action_138 (125) = happyShift action_140
action_138 (22) = happyGoto action_177
action_138 _ = happyReduce_26

action_139 _ = happyReduce_37

action_140 (67) = happyShift action_143
action_140 (92) = happyShift action_144
action_140 (93) = happyShift action_145
action_140 (94) = happyShift action_146
action_140 (95) = happyShift action_147
action_140 (96) = happyShift action_148
action_140 (97) = happyShift action_149
action_140 (98) = happyShift action_150
action_140 (99) = happyShift action_151
action_140 (100) = happyShift action_152
action_140 (101) = happyShift action_153
action_140 (102) = happyShift action_154
action_140 (103) = happyShift action_155
action_140 (104) = happyShift action_156
action_140 (105) = happyShift action_157
action_140 (106) = happyShift action_158
action_140 (107) = happyShift action_159
action_140 (108) = happyShift action_160
action_140 (109) = happyShift action_161
action_140 (110) = happyShift action_162
action_140 (111) = happyShift action_163
action_140 (112) = happyShift action_164
action_140 (113) = happyShift action_165
action_140 (114) = happyShift action_166
action_140 (115) = happyShift action_167
action_140 (116) = happyShift action_168
action_140 (117) = happyShift action_169
action_140 (118) = happyShift action_170
action_140 (119) = happyShift action_171
action_140 (120) = happyShift action_172
action_140 (121) = happyShift action_173
action_140 (122) = happyShift action_174
action_140 (123) = happyShift action_175
action_140 (126) = happyShift action_176
action_140 (23) = happyGoto action_141
action_140 (24) = happyGoto action_142
action_140 _ = happyReduce_40

action_141 (66) = happyShift action_197
action_141 _ = happyReduce_39

action_142 _ = happyReduce_41

action_143 _ = happyReduce_43

action_144 _ = happyReduce_45

action_145 _ = happyReduce_46

action_146 _ = happyReduce_47

action_147 _ = happyReduce_48

action_148 _ = happyReduce_49

action_149 _ = happyReduce_50

action_150 _ = happyReduce_51

action_151 _ = happyReduce_52

action_152 _ = happyReduce_53

action_153 _ = happyReduce_54

action_154 _ = happyReduce_55

action_155 _ = happyReduce_56

action_156 _ = happyReduce_57

action_157 _ = happyReduce_58

action_158 _ = happyReduce_59

action_159 _ = happyReduce_60

action_160 _ = happyReduce_61

action_161 _ = happyReduce_62

action_162 _ = happyReduce_63

action_163 _ = happyReduce_64

action_164 _ = happyReduce_65

action_165 _ = happyReduce_66

action_166 _ = happyReduce_67

action_167 _ = happyReduce_68

action_168 _ = happyReduce_69

action_169 _ = happyReduce_70

action_170 _ = happyReduce_71

action_171 _ = happyReduce_72

action_172 _ = happyReduce_73

action_173 _ = happyReduce_74

action_174 _ = happyReduce_75

action_175 _ = happyReduce_76

action_176 _ = happyReduce_44

action_177 _ = happyReduce_38

action_178 (53) = happyShift action_196
action_178 (66) = happyShift action_90
action_178 _ = happyFail (happyExpListPerState 178)

action_179 (51) = happyShift action_194
action_179 (66) = happyShift action_195
action_179 _ = happyFail (happyExpListPerState 179)

action_180 _ = happyReduce_115

action_181 (48) = happyShift action_61
action_181 (125) = happyShift action_62
action_181 (34) = happyGoto action_193
action_181 (35) = happyGoto action_60
action_181 _ = happyFail (happyExpListPerState 181)

action_182 _ = happyReduce_119

action_183 _ = happyReduce_120

action_184 (52) = happyShift action_191
action_184 (125) = happyShift action_192
action_184 (44) = happyGoto action_190
action_184 _ = happyFail (happyExpListPerState 184)

action_185 (125) = happyShift action_132
action_185 (42) = happyGoto action_189
action_185 (43) = happyGoto action_129
action_185 _ = happyReduce_125

action_186 _ = happyReduce_121

action_187 (125) = happyShift action_132
action_187 (43) = happyGoto action_188
action_187 _ = happyFail (happyExpListPerState 187)

action_188 _ = happyReduce_127

action_189 (66) = happyShift action_187
action_189 _ = happyReduce_123

action_190 (50) = happyShift action_201
action_190 (68) = happyShift action_202
action_190 (69) = happyShift action_203
action_190 _ = happyReduce_128

action_191 (48) = happyShift action_61
action_191 (125) = happyShift action_62
action_191 (33) = happyGoto action_200
action_191 (34) = happyGoto action_59
action_191 (35) = happyGoto action_60
action_191 _ = happyReduce_96

action_192 _ = happyReduce_133

action_193 _ = happyReduce_117

action_194 _ = happyReduce_95

action_195 (60) = happyShift action_182
action_195 (61) = happyShift action_183
action_195 (39) = happyGoto action_199
action_195 (40) = happyGoto action_181
action_195 _ = happyReduce_118

action_196 _ = happyReduce_94

action_197 (67) = happyShift action_143
action_197 (92) = happyShift action_144
action_197 (93) = happyShift action_145
action_197 (94) = happyShift action_146
action_197 (95) = happyShift action_147
action_197 (96) = happyShift action_148
action_197 (97) = happyShift action_149
action_197 (98) = happyShift action_150
action_197 (99) = happyShift action_151
action_197 (100) = happyShift action_152
action_197 (101) = happyShift action_153
action_197 (102) = happyShift action_154
action_197 (103) = happyShift action_155
action_197 (104) = happyShift action_156
action_197 (105) = happyShift action_157
action_197 (106) = happyShift action_158
action_197 (107) = happyShift action_159
action_197 (108) = happyShift action_160
action_197 (109) = happyShift action_161
action_197 (110) = happyShift action_162
action_197 (111) = happyShift action_163
action_197 (112) = happyShift action_164
action_197 (113) = happyShift action_165
action_197 (114) = happyShift action_166
action_197 (115) = happyShift action_167
action_197 (116) = happyShift action_168
action_197 (117) = happyShift action_169
action_197 (118) = happyShift action_170
action_197 (119) = happyShift action_171
action_197 (120) = happyShift action_172
action_197 (121) = happyShift action_173
action_197 (122) = happyShift action_174
action_197 (123) = happyShift action_175
action_197 (126) = happyShift action_176
action_197 (24) = happyGoto action_198
action_197 _ = happyFail (happyExpListPerState 197)

action_198 _ = happyReduce_42

action_199 _ = happyReduce_116

action_200 (53) = happyShift action_207
action_200 (66) = happyShift action_90
action_200 _ = happyFail (happyExpListPerState 200)

action_201 (51) = happyReduce_114
action_201 (60) = happyShift action_182
action_201 (61) = happyShift action_183
action_201 (66) = happyReduce_114
action_201 (38) = happyGoto action_206
action_201 (39) = happyGoto action_180
action_201 (40) = happyGoto action_181
action_201 _ = happyReduce_118

action_202 (52) = happyShift action_191
action_202 (125) = happyShift action_192
action_202 (44) = happyGoto action_205
action_202 _ = happyFail (happyExpListPerState 202)

action_203 (52) = happyShift action_191
action_203 (125) = happyShift action_192
action_203 (44) = happyGoto action_204
action_203 _ = happyFail (happyExpListPerState 203)

action_204 _ = happyReduce_132

action_205 _ = happyReduce_131

action_206 (51) = happyShift action_208
action_206 (66) = happyShift action_195
action_206 _ = happyFail (happyExpListPerState 206)

action_207 _ = happyReduce_129

action_208 _ = happyReduce_130

happyReduce_1 = happyReduce 4 4 happyReduction_1
happyReduction_1 ((HappyAbsSyn5  happy_var_4) `HappyStk`
	_ `HappyStk`
	(HappyTerminal happy_var_2) `HappyStk`
	(HappyTerminal happy_var_1) `HappyStk`
	happyRest)
	 = HappyAbsSyn4
		 (ModuleDecl (getSrcPos happy_var_1) (qualifyName happy_var_2) (reverse happy_var_4)
	) `HappyStk` happyRest

happyReduce_2 = happySpecReduce_1  5 happyReduction_2
happyReduction_2 (HappyAbsSyn6  happy_var_1)
	 =  HappyAbsSyn5
		 ([happy_var_1]
	)
happyReduction_2 _  = notHappyAtAll 

happyReduce_3 = happySpecReduce_2  5 happyReduction_3
happyReduction_3 (HappyAbsSyn6  happy_var_2)
	(HappyAbsSyn5  happy_var_1)
	 =  HappyAbsSyn5
		 (happy_var_2 : happy_var_1
	)
happyReduction_3 _ _  = notHappyAtAll 

happyReduce_4 = happySpecReduce_3  6 happyReduction_4
happyReduction_4 (HappyAbsSyn7  happy_var_3)
	_
	_
	 =  HappyAbsSyn6
		 (Imports $ reverse happy_var_3
	)
happyReduction_4 _ _ _  = notHappyAtAll 

happyReduce_5 = happySpecReduce_3  6 happyReduction_5
happyReduction_5 (HappyAbsSyn9  happy_var_3)
	_
	_
	 =  HappyAbsSyn6
		 (Types $ reverse happy_var_3
	)
happyReduction_5 _ _ _  = notHappyAtAll 

happyReduce_6 = happySpecReduce_3  6 happyReduction_6
happyReduction_6 (HappyAbsSyn13  happy_var_3)
	_
	_
	 =  HappyAbsSyn6
		 (Tags $ reverse happy_var_3
	)
happyReduction_6 _ _ _  = notHappyAtAll 

happyReduce_7 = happySpecReduce_3  6 happyReduction_7
happyReduction_7 (HappyAbsSyn16  happy_var_3)
	_
	_
	 =  HappyAbsSyn6
		 (Groups $ reverse happy_var_3
	)
happyReduction_7 _ _ _  = notHappyAtAll 

happyReduce_8 = happySpecReduce_3  6 happyReduction_8
happyReduction_8 (HappyAbsSyn25  happy_var_3)
	_
	_
	 =  HappyAbsSyn6
		 (Policies $ reverse happy_var_3
	)
happyReduction_8 _ _ _  = notHappyAtAll 

happyReduce_9 = happySpecReduce_3  6 happyReduction_9
happyReduction_9 (HappyAbsSyn45  happy_var_3)
	_
	_
	 =  HappyAbsSyn6
		 (Require $ reverse happy_var_3
	)
happyReduction_9 _ _ _  = notHappyAtAll 

happyReduce_10 = happySpecReduce_1  7 happyReduction_10
happyReduction_10 (HappyAbsSyn8  happy_var_1)
	 =  HappyAbsSyn7
		 ([happy_var_1]
	)
happyReduction_10 _  = notHappyAtAll 

happyReduce_11 = happySpecReduce_2  7 happyReduction_11
happyReduction_11 (HappyAbsSyn8  happy_var_2)
	(HappyAbsSyn7  happy_var_1)
	 =  HappyAbsSyn7
		 (happy_var_2 : happy_var_1
	)
happyReduction_11 _ _  = notHappyAtAll 

happyReduce_12 = happySpecReduce_1  8 happyReduction_12
happyReduction_12 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn8
		 (ImportDecl (getSrcPos happy_var_1) (qualifyName happy_var_1)
	)
happyReduction_12 _  = notHappyAtAll 

happyReduce_13 = happySpecReduce_1  9 happyReduction_13
happyReduction_13 (HappyAbsSyn10  happy_var_1)
	 =  HappyAbsSyn9
		 ([happy_var_1]
	)
happyReduction_13 _  = notHappyAtAll 

happyReduce_14 = happySpecReduce_2  9 happyReduction_14
happyReduction_14 (HappyAbsSyn10  happy_var_2)
	(HappyAbsSyn9  happy_var_1)
	 =  HappyAbsSyn9
		 (happy_var_2 : happy_var_1
	)
happyReduction_14 _ _  = notHappyAtAll 

happyReduce_15 = happyReduce 4 10 happyReduction_15
happyReduction_15 ((HappyAbsSyn11  happy_var_4) `HappyStk`
	_ `HappyStk`
	(HappyTerminal happy_var_2) `HappyStk`
	(HappyTerminal happy_var_1) `HappyStk`
	happyRest)
	 = HappyAbsSyn10
		 (TypeDecl (getSrcPos happy_var_1) (QType [getName happy_var_2]) happy_var_4
	) `HappyStk` happyRest

happyReduce_16 = happySpecReduce_2  11 happyReduction_16
happyReduction_16 (HappyAbsSyn12  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn11
		 (TDTInt (getSrcPos happy_var_1) happy_var_2
	)
happyReduction_16 _ _  = notHappyAtAll 

happyReduce_17 = happySpecReduce_3  12 happyReduction_17
happyReduction_17 _
	(HappyTerminal happy_var_2)
	_
	 =  HappyAbsSyn12
		 (Just (getIntLit happy_var_2)
	)
happyReduction_17 _ _ _  = notHappyAtAll 

happyReduce_18 = happySpecReduce_0  12 happyReduction_18
happyReduction_18  =  HappyAbsSyn12
		 (Nothing
	)

happyReduce_19 = happySpecReduce_1  13 happyReduction_19
happyReduction_19 (HappyAbsSyn14  happy_var_1)
	 =  HappyAbsSyn13
		 ([happy_var_1]
	)
happyReduction_19 _  = notHappyAtAll 

happyReduce_20 = happySpecReduce_3  13 happyReduction_20
happyReduction_20 (HappyAbsSyn14  happy_var_3)
	_
	(HappyAbsSyn13  happy_var_1)
	 =  HappyAbsSyn13
		 (happy_var_3 : happy_var_1
	)
happyReduction_20 _ _ _  = notHappyAtAll 

happyReduce_21 = happySpecReduce_2  14 happyReduction_21
happyReduction_21 (HappyAbsSyn15  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn14
		 (TagDecl (getSrcPos happy_var_1) (QTag [getName happy_var_1]) (reverse happy_var_2)
	)
happyReduction_21 _ _  = notHappyAtAll 

happyReduce_22 = happySpecReduce_0  15 happyReduction_22
happyReduction_22  =  HappyAbsSyn15
		 ([]
	)

happyReduce_23 = happySpecReduce_2  15 happyReduction_23
happyReduction_23 (HappyTerminal happy_var_2)
	(HappyAbsSyn15  happy_var_1)
	 =  HappyAbsSyn15
		 (QType [getName happy_var_2] : happy_var_1
	)
happyReduction_23 _ _  = notHappyAtAll 

happyReduce_24 = happySpecReduce_1  16 happyReduction_24
happyReduction_24 (HappyAbsSyn17  happy_var_1)
	 =  HappyAbsSyn16
		 ([happy_var_1]
	)
happyReduction_24 _  = notHappyAtAll 

happyReduce_25 = happySpecReduce_2  16 happyReduction_25
happyReduction_25 (HappyAbsSyn17  happy_var_2)
	(HappyAbsSyn16  happy_var_1)
	 =  HappyAbsSyn16
		 (happy_var_2 : happy_var_1
	)
happyReduction_25 _ _  = notHappyAtAll 

happyReduce_26 = happyReduce 8 17 happyReduction_26
happyReduction_26 ((HappyAbsSyn21  happy_var_8) `HappyStk`
	_ `HappyStk`
	(HappyAbsSyn18  happy_var_6) `HappyStk`
	_ `HappyStk`
	(HappyAbsSyn18  happy_var_4) `HappyStk`
	_ `HappyStk`
	(HappyTerminal happy_var_2) `HappyStk`
	(HappyTerminal happy_var_1) `HappyStk`
	happyRest)
	 = HappyAbsSyn17
		 (GroupDecl (getSrcPos happy_var_1) (QGroup [getName happy_var_2]) (reverse happy_var_4)
                  (reverse happy_var_6) (reverse happy_var_8)
	) `HappyStk` happyRest

happyReduce_27 = happySpecReduce_0  18 happyReduction_27
happyReduction_27  =  HappyAbsSyn18
		 ([]
	)

happyReduce_28 = happySpecReduce_1  18 happyReduction_28
happyReduction_28 (HappyAbsSyn19  happy_var_1)
	 =  HappyAbsSyn18
		 ([happy_var_1]
	)
happyReduction_28 _  = notHappyAtAll 

happyReduce_29 = happySpecReduce_3  18 happyReduction_29
happyReduction_29 (HappyAbsSyn19  happy_var_3)
	_
	(HappyAbsSyn18  happy_var_1)
	 =  HappyAbsSyn18
		 (happy_var_3 : happy_var_1
	)
happyReduction_29 _ _ _  = notHappyAtAll 

happyReduce_30 = happySpecReduce_3  19 happyReduction_30
happyReduction_30 (HappyTerminal happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyAbsSyn20  happy_var_1)
	 =  HappyAbsSyn19
		 (GroupParam (getSrcPos happy_var_2) happy_var_1 (QVar [getName happy_var_3])
	)
happyReduction_30 _ _ _  = notHappyAtAll 

happyReduce_31 = happySpecReduce_1  20 happyReduction_31
happyReduction_31 _
	 =  HappyAbsSyn20
		 (RD
	)

happyReduce_32 = happySpecReduce_1  20 happyReduction_32
happyReduction_32 _
	 =  HappyAbsSyn20
		 (RS1
	)

happyReduce_33 = happySpecReduce_1  20 happyReduction_33
happyReduction_33 _
	 =  HappyAbsSyn20
		 (RS2
	)

happyReduce_34 = happySpecReduce_1  20 happyReduction_34
happyReduction_34 _
	 =  HappyAbsSyn20
		 (RS3
	)

happyReduce_35 = happySpecReduce_1  20 happyReduction_35
happyReduction_35 _
	 =  HappyAbsSyn20
		 (Csr
	)

happyReduce_36 = happySpecReduce_1  20 happyReduction_36
happyReduction_36 _
	 =  HappyAbsSyn20
		 (Mem
	)

happyReduce_37 = happySpecReduce_1  21 happyReduction_37
happyReduction_37 (HappyAbsSyn22  happy_var_1)
	 =  HappyAbsSyn21
		 ([happy_var_1]
	)
happyReduction_37 _  = notHappyAtAll 

happyReduce_38 = happySpecReduce_2  21 happyReduction_38
happyReduction_38 (HappyAbsSyn22  happy_var_2)
	(HappyAbsSyn21  happy_var_1)
	 =  HappyAbsSyn21
		 (happy_var_2 : happy_var_1
	)
happyReduction_38 _ _  = notHappyAtAll 

happyReduce_39 = happySpecReduce_2  22 happyReduction_39
happyReduction_39 (HappyAbsSyn23  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn22
		 (Asm (getSrcPos happy_var_1) (getName happy_var_1)
            (if null happy_var_2 then Nothing else Just (reverse happy_var_2))
	)
happyReduction_39 _ _  = notHappyAtAll 

happyReduce_40 = happySpecReduce_0  23 happyReduction_40
happyReduction_40  =  HappyAbsSyn23
		 ([]
	)

happyReduce_41 = happySpecReduce_1  23 happyReduction_41
happyReduction_41 (HappyAbsSyn24  happy_var_1)
	 =  HappyAbsSyn23
		 ([happy_var_1]
	)
happyReduction_41 _  = notHappyAtAll 

happyReduce_42 = happySpecReduce_3  23 happyReduction_42
happyReduction_42 (HappyAbsSyn24  happy_var_3)
	_
	(HappyAbsSyn23  happy_var_1)
	 =  HappyAbsSyn23
		 (happy_var_3 : happy_var_1
	)
happyReduction_42 _ _ _  = notHappyAtAll 

happyReduce_43 = happySpecReduce_1  24 happyReduction_43
happyReduction_43 _
	 =  HappyAbsSyn24
		 (AnyOp
	)

happyReduce_44 = happySpecReduce_1  24 happyReduction_44
happyReduction_44 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn24
		 (Const $ toInteger (getIntLit happy_var_1)
	)
happyReduction_44 _  = notHappyAtAll 

happyReduce_45 = happySpecReduce_1  24 happyReduction_45
happyReduction_45 _
	 =  HappyAbsSyn24
		 (Reg X0
	)

happyReduce_46 = happySpecReduce_1  24 happyReduction_46
happyReduction_46 _
	 =  HappyAbsSyn24
		 (Reg X1
	)

happyReduce_47 = happySpecReduce_1  24 happyReduction_47
happyReduction_47 _
	 =  HappyAbsSyn24
		 (Reg X2
	)

happyReduce_48 = happySpecReduce_1  24 happyReduction_48
happyReduction_48 _
	 =  HappyAbsSyn24
		 (Reg X3
	)

happyReduce_49 = happySpecReduce_1  24 happyReduction_49
happyReduction_49 _
	 =  HappyAbsSyn24
		 (Reg X4
	)

happyReduce_50 = happySpecReduce_1  24 happyReduction_50
happyReduction_50 _
	 =  HappyAbsSyn24
		 (Reg X5
	)

happyReduce_51 = happySpecReduce_1  24 happyReduction_51
happyReduction_51 _
	 =  HappyAbsSyn24
		 (Reg X6
	)

happyReduce_52 = happySpecReduce_1  24 happyReduction_52
happyReduction_52 _
	 =  HappyAbsSyn24
		 (Reg X7
	)

happyReduce_53 = happySpecReduce_1  24 happyReduction_53
happyReduction_53 _
	 =  HappyAbsSyn24
		 (Reg X8
	)

happyReduce_54 = happySpecReduce_1  24 happyReduction_54
happyReduction_54 _
	 =  HappyAbsSyn24
		 (Reg X9
	)

happyReduce_55 = happySpecReduce_1  24 happyReduction_55
happyReduction_55 _
	 =  HappyAbsSyn24
		 (Reg X10
	)

happyReduce_56 = happySpecReduce_1  24 happyReduction_56
happyReduction_56 _
	 =  HappyAbsSyn24
		 (Reg X11
	)

happyReduce_57 = happySpecReduce_1  24 happyReduction_57
happyReduction_57 _
	 =  HappyAbsSyn24
		 (Reg X12
	)

happyReduce_58 = happySpecReduce_1  24 happyReduction_58
happyReduction_58 _
	 =  HappyAbsSyn24
		 (Reg X13
	)

happyReduce_59 = happySpecReduce_1  24 happyReduction_59
happyReduction_59 _
	 =  HappyAbsSyn24
		 (Reg X14
	)

happyReduce_60 = happySpecReduce_1  24 happyReduction_60
happyReduction_60 _
	 =  HappyAbsSyn24
		 (Reg X15
	)

happyReduce_61 = happySpecReduce_1  24 happyReduction_61
happyReduction_61 _
	 =  HappyAbsSyn24
		 (Reg X16
	)

happyReduce_62 = happySpecReduce_1  24 happyReduction_62
happyReduction_62 _
	 =  HappyAbsSyn24
		 (Reg X17
	)

happyReduce_63 = happySpecReduce_1  24 happyReduction_63
happyReduction_63 _
	 =  HappyAbsSyn24
		 (Reg X18
	)

happyReduce_64 = happySpecReduce_1  24 happyReduction_64
happyReduction_64 _
	 =  HappyAbsSyn24
		 (Reg X19
	)

happyReduce_65 = happySpecReduce_1  24 happyReduction_65
happyReduction_65 _
	 =  HappyAbsSyn24
		 (Reg X20
	)

happyReduce_66 = happySpecReduce_1  24 happyReduction_66
happyReduction_66 _
	 =  HappyAbsSyn24
		 (Reg X21
	)

happyReduce_67 = happySpecReduce_1  24 happyReduction_67
happyReduction_67 _
	 =  HappyAbsSyn24
		 (Reg X22
	)

happyReduce_68 = happySpecReduce_1  24 happyReduction_68
happyReduction_68 _
	 =  HappyAbsSyn24
		 (Reg X23
	)

happyReduce_69 = happySpecReduce_1  24 happyReduction_69
happyReduction_69 _
	 =  HappyAbsSyn24
		 (Reg X24
	)

happyReduce_70 = happySpecReduce_1  24 happyReduction_70
happyReduction_70 _
	 =  HappyAbsSyn24
		 (Reg X25
	)

happyReduce_71 = happySpecReduce_1  24 happyReduction_71
happyReduction_71 _
	 =  HappyAbsSyn24
		 (Reg X26
	)

happyReduce_72 = happySpecReduce_1  24 happyReduction_72
happyReduction_72 _
	 =  HappyAbsSyn24
		 (Reg X27
	)

happyReduce_73 = happySpecReduce_1  24 happyReduction_73
happyReduction_73 _
	 =  HappyAbsSyn24
		 (Reg X28
	)

happyReduce_74 = happySpecReduce_1  24 happyReduction_74
happyReduction_74 _
	 =  HappyAbsSyn24
		 (Reg X29
	)

happyReduce_75 = happySpecReduce_1  24 happyReduction_75
happyReduction_75 _
	 =  HappyAbsSyn24
		 (Reg X30
	)

happyReduce_76 = happySpecReduce_1  24 happyReduction_76
happyReduction_76 _
	 =  HappyAbsSyn24
		 (Reg X31
	)

happyReduce_77 = happySpecReduce_1  25 happyReduction_77
happyReduction_77 (HappyAbsSyn26  happy_var_1)
	 =  HappyAbsSyn25
		 ([happy_var_1]
	)
happyReduction_77 _  = notHappyAtAll 

happyReduce_78 = happySpecReduce_2  25 happyReduction_78
happyReduction_78 (HappyAbsSyn26  happy_var_2)
	(HappyAbsSyn25  happy_var_1)
	 =  HappyAbsSyn25
		 (happy_var_2 : happy_var_1
	)
happyReduction_78 _ _  = notHappyAtAll 

happyReduce_79 = happyReduce 4 26 happyReduction_79
happyReduction_79 ((HappyAbsSyn28  happy_var_4) `HappyStk`
	_ `HappyStk`
	(HappyTerminal happy_var_2) `HappyStk`
	(HappyAbsSyn27  happy_var_1) `HappyStk`
	happyRest)
	 = HappyAbsSyn26
		 (PolicyDecl (getSrcPos happy_var_2) happy_var_1 (QPolicy [getName happy_var_2]) happy_var_4
	) `HappyStk` happyRest

happyReduce_80 = happySpecReduce_0  27 happyReduction_80
happyReduction_80  =  HappyAbsSyn27
		 (PLLocal
	)

happyReduce_81 = happySpecReduce_1  27 happyReduction_81
happyReduction_81 _
	 =  HappyAbsSyn27
		 (PLGlobal
	)

happyReduce_82 = happySpecReduce_1  28 happyReduction_82
happyReduction_82 (HappyAbsSyn28  happy_var_1)
	 =  HappyAbsSyn28
		 (happy_var_1
	)
happyReduction_82 _  = notHappyAtAll 

happyReduce_83 = happySpecReduce_3  28 happyReduction_83
happyReduction_83 (HappyAbsSyn28  happy_var_3)
	_
	(HappyAbsSyn28  happy_var_1)
	 =  HappyAbsSyn28
		 (PECompModule (policyExSrcPos happy_var_1) happy_var_1 happy_var_3
	)
happyReduction_83 _ _ _  = notHappyAtAll 

happyReduce_84 = happySpecReduce_3  28 happyReduction_84
happyReduction_84 (HappyAbsSyn28  happy_var_3)
	_
	(HappyAbsSyn28  happy_var_1)
	 =  HappyAbsSyn28
		 (PECompExclusive (policyExSrcPos happy_var_1) happy_var_1 happy_var_3
	)
happyReduction_84 _ _ _  = notHappyAtAll 

happyReduce_85 = happySpecReduce_3  28 happyReduction_85
happyReduction_85 (HappyAbsSyn28  happy_var_3)
	_
	(HappyAbsSyn28  happy_var_1)
	 =  HappyAbsSyn28
		 (PECompPriority (policyExSrcPos happy_var_1) happy_var_1 happy_var_3
	)
happyReduction_85 _ _ _  = notHappyAtAll 

happyReduce_86 = happySpecReduce_1  28 happyReduction_86
happyReduction_86 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn28
		 (PENoChecks (getSrcPos happy_var_1)
	)
happyReduction_86 _  = notHappyAtAll 

happyReduce_87 = happySpecReduce_1  28 happyReduction_87
happyReduction_87 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn28
		 (PEVar (getSrcPos happy_var_1) (QPolicy [getName happy_var_1])
	)
happyReduction_87 _  = notHappyAtAll 

happyReduce_88 = happyReduce 5 29 happyReduction_88
happyReduction_88 (_ `HappyStk`
	(HappyAbsSyn41  happy_var_4) `HappyStk`
	(HappyAbsSyn30  happy_var_3) `HappyStk`
	_ `HappyStk`
	(HappyTerminal happy_var_1) `HappyStk`
	happyRest)
	 = HappyAbsSyn28
		 (PERule (getSrcPos happy_var_1) $
            RuleClause (getSrcPos happy_var_1) (QGroup [getName happy_var_1]) (reverse happy_var_3) happy_var_4
	) `HappyStk` happyRest

happyReduce_89 = happySpecReduce_0  30 happyReduction_89
happyReduction_89  =  HappyAbsSyn30
		 ([]
	)

happyReduce_90 = happySpecReduce_1  30 happyReduction_90
happyReduction_90 (HappyAbsSyn31  happy_var_1)
	 =  HappyAbsSyn30
		 ([happy_var_1]
	)
happyReduction_90 _  = notHappyAtAll 

happyReduce_91 = happySpecReduce_3  30 happyReduction_91
happyReduction_91 (HappyAbsSyn31  happy_var_3)
	_
	(HappyAbsSyn30  happy_var_1)
	 =  HappyAbsSyn30
		 (happy_var_3 : happy_var_1
	)
happyReduction_91 _ _ _  = notHappyAtAll 

happyReduce_92 = happySpecReduce_3  31 happyReduction_92
happyReduction_92 (HappyAbsSyn32  happy_var_3)
	_
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn31
		 (BoundGroupPat (getSrcPos happy_var_1) (QVar [getName happy_var_1]) happy_var_3
	)
happyReduction_92 _ _ _  = notHappyAtAll 

happyReduce_93 = happySpecReduce_1  32 happyReduction_93
happyReduction_93 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn32
		 (TSPAny $ getSrcPos happy_var_1
	)
happyReduction_93 _  = notHappyAtAll 

happyReduce_94 = happySpecReduce_3  32 happyReduction_94
happyReduction_94 _
	(HappyAbsSyn33  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn32
		 (TSPExact (getSrcPos happy_var_1) (reverse happy_var_2)
	)
happyReduction_94 _ _ _  = notHappyAtAll 

happyReduce_95 = happySpecReduce_3  32 happyReduction_95
happyReduction_95 _
	(HappyAbsSyn38  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn32
		 (TSPAtLeast (getSrcPos happy_var_1) (reverse happy_var_2)
	)
happyReduction_95 _ _ _  = notHappyAtAll 

happyReduce_96 = happySpecReduce_0  33 happyReduction_96
happyReduction_96  =  HappyAbsSyn33
		 ([]
	)

happyReduce_97 = happySpecReduce_1  33 happyReduction_97
happyReduction_97 (HappyAbsSyn34  happy_var_1)
	 =  HappyAbsSyn33
		 ([happy_var_1]
	)
happyReduction_97 _  = notHappyAtAll 

happyReduce_98 = happySpecReduce_3  33 happyReduction_98
happyReduction_98 (HappyAbsSyn34  happy_var_3)
	_
	(HappyAbsSyn33  happy_var_1)
	 =  HappyAbsSyn33
		 (happy_var_3 : happy_var_1
	)
happyReduction_98 _ _ _  = notHappyAtAll 

happyReduce_99 = happySpecReduce_1  34 happyReduction_99
happyReduction_99 (HappyAbsSyn34  happy_var_1)
	 =  HappyAbsSyn34
		 (happy_var_1
	)
happyReduction_99 _  = notHappyAtAll 

happyReduce_100 = happySpecReduce_3  34 happyReduction_100
happyReduction_100 _
	(HappyAbsSyn34  happy_var_2)
	_
	 =  HappyAbsSyn34
		 (happy_var_2
	)
happyReduction_100 _ _ _  = notHappyAtAll 

happyReduce_101 = happySpecReduce_2  35 happyReduction_101
happyReduction_101 (HappyAbsSyn36  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn34
		 (Tag (getSrcPos happy_var_1) (QTag [getName happy_var_1]) (reverse happy_var_2)
	)
happyReduction_101 _ _  = notHappyAtAll 

happyReduce_102 = happySpecReduce_0  36 happyReduction_102
happyReduction_102  =  HappyAbsSyn36
		 ([]
	)

happyReduce_103 = happySpecReduce_2  36 happyReduction_103
happyReduction_103 (HappyAbsSyn37  happy_var_2)
	(HappyAbsSyn36  happy_var_1)
	 =  HappyAbsSyn36
		 (happy_var_2 : happy_var_1
	)
happyReduction_103 _ _  = notHappyAtAll 

happyReduce_104 = happySpecReduce_1  37 happyReduction_104
happyReduction_104 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn37
		 (TFNew (getSrcPos happy_var_1)
	)
happyReduction_104 _  = notHappyAtAll 

happyReduce_105 = happySpecReduce_1  37 happyReduction_105
happyReduction_105 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn37
		 (TFVar (getSrcPos happy_var_1) (QVar [getName happy_var_1])
	)
happyReduction_105 _  = notHappyAtAll 

happyReduce_106 = happySpecReduce_1  37 happyReduction_106
happyReduction_106 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn37
		 (TFAny (getSrcPos happy_var_1)
	)
happyReduction_106 _  = notHappyAtAll 

happyReduce_107 = happySpecReduce_1  37 happyReduction_107
happyReduction_107 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn37
		 (TFInt (getSrcPos happy_var_1) (getIntLit happy_var_1)
	)
happyReduction_107 _  = notHappyAtAll 

happyReduce_108 = happySpecReduce_3  37 happyReduction_108
happyReduction_108 _
	(HappyAbsSyn37  happy_var_2)
	_
	 =  HappyAbsSyn37
		 (happy_var_2
	)
happyReduction_108 _ _ _  = notHappyAtAll 

happyReduce_109 = happySpecReduce_3  37 happyReduction_109
happyReduction_109 (HappyAbsSyn37  happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyAbsSyn37  happy_var_1)
	 =  HappyAbsSyn37
		 (TFBinOp (getSrcPos happy_var_2) TFBOPlus happy_var_1 happy_var_3
	)
happyReduction_109 _ _ _  = notHappyAtAll 

happyReduce_110 = happySpecReduce_3  37 happyReduction_110
happyReduction_110 (HappyAbsSyn37  happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyAbsSyn37  happy_var_1)
	 =  HappyAbsSyn37
		 (TFBinOp (getSrcPos happy_var_2) TFBOMinus happy_var_1 happy_var_3
	)
happyReduction_110 _ _ _  = notHappyAtAll 

happyReduce_111 = happySpecReduce_3  37 happyReduction_111
happyReduction_111 (HappyAbsSyn37  happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyAbsSyn37  happy_var_1)
	 =  HappyAbsSyn37
		 (TFBinOp (getSrcPos happy_var_2) TFBOTimes happy_var_1 happy_var_3
	)
happyReduction_111 _ _ _  = notHappyAtAll 

happyReduce_112 = happySpecReduce_3  37 happyReduction_112
happyReduction_112 (HappyAbsSyn37  happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyAbsSyn37  happy_var_1)
	 =  HappyAbsSyn37
		 (TFBinOp (getSrcPos happy_var_2) TFBODiv happy_var_1 happy_var_3
	)
happyReduction_112 _ _ _  = notHappyAtAll 

happyReduce_113 = happySpecReduce_3  37 happyReduction_113
happyReduction_113 (HappyAbsSyn37  happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyAbsSyn37  happy_var_1)
	 =  HappyAbsSyn37
		 (TFBinOp (getSrcPos happy_var_2) TFBOMod happy_var_1 happy_var_3
	)
happyReduction_113 _ _ _  = notHappyAtAll 

happyReduce_114 = happySpecReduce_0  38 happyReduction_114
happyReduction_114  =  HappyAbsSyn38
		 ([]
	)

happyReduce_115 = happySpecReduce_1  38 happyReduction_115
happyReduction_115 (HappyAbsSyn39  happy_var_1)
	 =  HappyAbsSyn38
		 ([happy_var_1]
	)
happyReduction_115 _  = notHappyAtAll 

happyReduce_116 = happySpecReduce_3  38 happyReduction_116
happyReduction_116 (HappyAbsSyn39  happy_var_3)
	_
	(HappyAbsSyn38  happy_var_1)
	 =  HappyAbsSyn38
		 (happy_var_3 : happy_var_1
	)
happyReduction_116 _ _ _  = notHappyAtAll 

happyReduce_117 = happySpecReduce_2  39 happyReduction_117
happyReduction_117 (HappyAbsSyn34  happy_var_2)
	(HappyAbsSyn40  happy_var_1)
	 =  HappyAbsSyn39
		 (happy_var_1 (pos happy_var_2) happy_var_2
	)
happyReduction_117 _ _  = notHappyAtAll 

happyReduce_118 = happySpecReduce_0  40 happyReduction_118
happyReduction_118  =  HappyAbsSyn40
		 (TagEx
	)

happyReduce_119 = happySpecReduce_1  40 happyReduction_119
happyReduction_119 _
	 =  HappyAbsSyn40
		 (TagPlusEx
	)

happyReduce_120 = happySpecReduce_1  40 happyReduction_120
happyReduction_120 _
	 =  HappyAbsSyn40
		 (TagMinusEx
	)

happyReduce_121 = happySpecReduce_3  41 happyReduction_121
happyReduction_121 (HappyTerminal (L _ (TStringLit happy_var_3)))
	(HappyTerminal happy_var_2)
	_
	 =  HappyAbsSyn41
		 (RRFail (getSrcPos happy_var_2) happy_var_3
	)
happyReduction_121 _ _ _  = notHappyAtAll 

happyReduce_122 = happySpecReduce_2  41 happyReduction_122
happyReduction_122 (HappyTerminal happy_var_2)
	_
	 =  HappyAbsSyn41
		 (RRUpdate (getSrcPos happy_var_2) []
	)
happyReduction_122 _ _  = notHappyAtAll 

happyReduce_123 = happyReduce 4 41 happyReduction_123
happyReduction_123 ((HappyAbsSyn42  happy_var_4) `HappyStk`
	_ `HappyStk`
	(HappyTerminal happy_var_2) `HappyStk`
	_ `HappyStk`
	happyRest)
	 = HappyAbsSyn41
		 (RRUpdate (getSrcPos happy_var_2) happy_var_4
	) `HappyStk` happyRest

happyReduce_124 = happySpecReduce_2  41 happyReduction_124
happyReduction_124 (HappyAbsSyn42  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn41
		 (RRUpdate (getSrcPos happy_var_1) happy_var_2
	)
happyReduction_124 _ _  = notHappyAtAll 

happyReduce_125 = happySpecReduce_0  42 happyReduction_125
happyReduction_125  =  HappyAbsSyn42
		 ([]
	)

happyReduce_126 = happySpecReduce_1  42 happyReduction_126
happyReduction_126 (HappyAbsSyn43  happy_var_1)
	 =  HappyAbsSyn42
		 ([happy_var_1]
	)
happyReduction_126 _  = notHappyAtAll 

happyReduce_127 = happySpecReduce_3  42 happyReduction_127
happyReduction_127 (HappyAbsSyn43  happy_var_3)
	_
	(HappyAbsSyn42  happy_var_1)
	 =  HappyAbsSyn42
		 (happy_var_3 : happy_var_1
	)
happyReduction_127 _ _ _  = notHappyAtAll 

happyReduce_128 = happySpecReduce_3  43 happyReduction_128
happyReduction_128 (HappyAbsSyn44  happy_var_3)
	_
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn43
		 (BoundGroupEx (getSrcPos happy_var_1) (QVar [getName happy_var_1]) happy_var_3
	)
happyReduction_128 _ _ _  = notHappyAtAll 

happyReduce_129 = happySpecReduce_3  44 happyReduction_129
happyReduction_129 _
	(HappyAbsSyn33  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn44
		 (TSEExact (getSrcPos happy_var_1) (reverse happy_var_2)
	)
happyReduction_129 _ _ _  = notHappyAtAll 

happyReduce_130 = happyReduce 4 44 happyReduction_130
happyReduction_130 (_ `HappyStk`
	(HappyAbsSyn38  happy_var_3) `HappyStk`
	(HappyTerminal happy_var_2) `HappyStk`
	(HappyAbsSyn44  happy_var_1) `HappyStk`
	happyRest)
	 = HappyAbsSyn44
		 (TSEModify (getSrcPos happy_var_2) happy_var_1 (reverse happy_var_3)
	) `HappyStk` happyRest

happyReduce_131 = happySpecReduce_3  44 happyReduction_131
happyReduction_131 (HappyAbsSyn44  happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyAbsSyn44  happy_var_1)
	 =  HappyAbsSyn44
		 (TSEUnion (getSrcPos happy_var_2) happy_var_1 happy_var_3
	)
happyReduction_131 _ _ _  = notHappyAtAll 

happyReduce_132 = happySpecReduce_3  44 happyReduction_132
happyReduction_132 (HappyAbsSyn44  happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyAbsSyn44  happy_var_1)
	 =  HappyAbsSyn44
		 (TSEIntersect (getSrcPos happy_var_2) happy_var_1 happy_var_3
	)
happyReduction_132 _ _ _  = notHappyAtAll 

happyReduce_133 = happySpecReduce_1  44 happyReduction_133
happyReduction_133 (HappyTerminal happy_var_1)
	 =  HappyAbsSyn44
		 (TSEVar (getSrcPos happy_var_1) (QVar [getName happy_var_1])
	)
happyReduction_133 _  = notHappyAtAll 

happyReduce_134 = happySpecReduce_1  45 happyReduction_134
happyReduction_134 (HappyAbsSyn46  happy_var_1)
	 =  HappyAbsSyn45
		 ([happy_var_1]
	)
happyReduction_134 _  = notHappyAtAll 

happyReduce_135 = happySpecReduce_2  45 happyReduction_135
happyReduction_135 (HappyAbsSyn46  happy_var_2)
	(HappyAbsSyn45  happy_var_1)
	 =  HappyAbsSyn45
		 (happy_var_2 : happy_var_1
	)
happyReduction_135 _ _  = notHappyAtAll 

happyReduce_136 = happySpecReduce_3  46 happyReduction_136
happyReduction_136 (HappyAbsSyn47  happy_var_3)
	(HappyTerminal happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn46
		 (Init (getSrcPos happy_var_1) (qualifyName happy_var_2) happy_var_3
	)
happyReduction_136 _ _ _  = notHappyAtAll 

happyReduce_137 = happySpecReduce_3  47 happyReduction_137
happyReduction_137 _
	(HappyAbsSyn33  happy_var_2)
	(HappyTerminal happy_var_1)
	 =  HappyAbsSyn47
		 (ISExact (getSrcPos happy_var_1) (reverse happy_var_2)
	)
happyReduction_137 _ _ _  = notHappyAtAll 

happyNewToken action sts stk
	= lexer(\tk -> 
	let cont i = action i i tk (HappyState action) sts stk in
	case tk of {
	L _ TEOF -> action 128 128 tk (HappyState action) sts stk;
	L _ TOParen -> cont 48;
	L _ TCParen -> cont 49;
	L _ TOBracket -> cont 50;
	L _ TCBracket -> cont 51;
	L _ TOCurly -> cont 52;
	L _ TCCurly -> cont 53;
	L _ TMatch -> cont 54;
	L _ TArrow -> cont 55;
	L _ TAssign -> cont 56;
	L _ TCompSeq -> cont 57;
	L _ TCompExcl -> cont 58;
	L _ TCompModule -> cont 59;
	L _ TPlus -> cont 60;
	L _ TMinus -> cont 61;
	L _ TDiv -> cont 62;
	L _ TMod -> cont 63;
	L _ TUnderscore -> cont 64;
	L _ TColon -> cont 65;
	L _ TComma -> cont 66;
	L _ TStar -> cont 67;
	L _ TUnion -> cont 68;
	L _ TIntersection -> cont 69;
	L _ TModule -> cont 70;
	L _ TImport -> cont 71;
	L _ TType -> cont 72;
	L _ TData -> cont 73;
	L _ TInt -> cont 74;
	L _ TMetadata -> cont 75;
	L _ TGroup -> cont 76;
	L _ TGrp -> cont 77;
	L _ TRD -> cont 78;
	L _ TRS1 -> cont 79;
	L _ TRS2 -> cont 80;
	L _ TRS3 -> cont 81;
	L _ TCSR -> cont 82;
	L _ TMEM -> cont 83;
	L _ TPolicy -> cont 84;
	L _ TGlobal -> cont 85;
	L _ TFail -> cont 86;
	L _ TAllow -> cont 87;
	L _ TWith -> cont 88;
	L _ TNew -> cont 89;
	L _ TRequire -> cont 90;
	L _ TInit -> cont 91;
	L _ TX0 -> cont 92;
	L _ TX1 -> cont 93;
	L _ TX2 -> cont 94;
	L _ TX3 -> cont 95;
	L _ TX4 -> cont 96;
	L _ TX5 -> cont 97;
	L _ TX6 -> cont 98;
	L _ TX7 -> cont 99;
	L _ TX8 -> cont 100;
	L _ TX9 -> cont 101;
	L _ TX10 -> cont 102;
	L _ TX11 -> cont 103;
	L _ TX12 -> cont 104;
	L _ TX13 -> cont 105;
	L _ TX14 -> cont 106;
	L _ TX15 -> cont 107;
	L _ TX16 -> cont 108;
	L _ TX17 -> cont 109;
	L _ TX18 -> cont 110;
	L _ TX19 -> cont 111;
	L _ TX20 -> cont 112;
	L _ TX21 -> cont 113;
	L _ TX22 -> cont 114;
	L _ TX23 -> cont 115;
	L _ TX24 -> cont 116;
	L _ TX25 -> cont 117;
	L _ TX26 -> cont 118;
	L _ TX27 -> cont 119;
	L _ TX28 -> cont 120;
	L _ TX29 -> cont 121;
	L _ TX30 -> cont 122;
	L _ TX31 -> cont 123;
	L _ TNOCHECKS -> cont 124;
	L _ (TID _) -> cont 125;
	L _ (TIntLit _) -> cont 126;
	L _ (TStringLit happy_dollar_dollar) -> cont 127;
	_ -> happyError' (tk, [])
	})

happyError_ explist 128 tk = happyError' (tk, explist)
happyError_ explist _ tk = happyError' (tk, explist)

happyThen :: () => P a -> (a -> P b) -> P b
happyThen = (>>=)
happyReturn :: () => a -> P a
happyReturn = (return)
happyThen1 :: () => P a -> (a -> P b) -> P b
happyThen1 = happyThen
happyReturn1 :: () => a -> P a
happyReturn1 = happyReturn
happyError' :: () => (((Located Token)), [String]) -> P a
happyError' tk = (\(tokens, explist) -> happyError) tk
parseModule = happySomeParser where
 happySomeParser = happyThen (happyParse action_0) (\x -> case x of {HappyAbsSyn4 z -> happyReturn z; _other -> notHappyAtAll })

happySeq = happyDontSeq


happyError :: P a
happyError = alexError "parse error."

separate :: String -> [String]
separate = sep [] []
  where
    sep :: [String] -> String -> String -> [String]
    sep acc []    []      = reverse acc
    sep acc chunk []      = reverse (reverse chunk : acc)
    sep acc []    ('.':s) = sep acc [] s
    sep acc chunk ('.':s) = sep (reverse chunk : acc) [] s
    sep acc chunk (c:s)   = sep acc (c:chunk) s

getName :: Located Token -> String
getName (L _ (TID nm)) = nm
getName (L _ t) = error $
     "Impossible: parser encountered non-identifier token ("
  ++ show t ++ ") after checking for identifier in getName."

qualifyName :: Located Token -> [String]
qualifyName t = separate $ getName t

getIntLit :: Located Token -> Int
getIntLit (L _ (TIntLit i)) = i
getIntLit (L _ t) = error $
     "Impossible: parser encountered non-int literal token ("
  ++ show t ++ ") after checking for int literal in getIntLit."

polParse :: Options -> ModName -> IO (Either ErrMsg (ModuleDecl QSym))
polParse opts qmn = do
  impls <- findImplementations
  case impls of
    [] -> error $ "Couldn't find file corresponding to module "
               ++ dotName qmn ++ ".  Searched:\n"
               ++ concatMap (\fp -> "  " ++ fp ++ "\n") moduleDirs
    _:_:_ -> error $ "Found multiple conflicting implementations of module "
                   ++ dotName qmn ++ " at:\n"
                   ++ concatMap (\fp -> "  " ++ fp ++ "\n") impls
    impl:[] -> do
      putStrLn ("Reading file: " ++ impl)
      contents <- readFile impl
      return $ runP impl contents parseModule
  where
    moduleDirs :: [FilePath]
    moduleDirs = optModuleDir opts

    findImplementations :: IO [FilePath]
    findImplementations = foldM addIfExists [] moduleDirs
      where
        addIfExists :: [FilePath] -> FilePath -> IO [FilePath]
        addIfExists acc moddir = do
          let file = moduleFile moddir qmn
          exists <- doesFileExist file
          return $ if exists then file:acc else acc

moduleFile :: FilePath -> [FilePath] -> FilePath
moduleFile moddir qmn = moddir </> (joinPath qmn <.> "dpl")

policyExSrcPos :: PolicyEx a -> SrcPos
policyExSrcPos (PEVar sp _) = sp
policyExSrcPos (PECompExclusive sp _ _) = sp
policyExSrcPos (PECompPriority sp _ _)  = sp
policyExSrcPos (PECompModule sp _ _)    = sp
policyExSrcPos (PERule sp _)            = sp
policyExSrcPos (PENoChecks sp)          = sp

-- Useful for debugging
--main = do
--  s <- getContents
--  print $ runP "<stdin>" s parseModule
{-# LINE 1 "templates/GenericTemplate.hs" #-}
{-# LINE 1 "templates/GenericTemplate.hs" #-}
{-# LINE 1 "<built-in>" #-}
{-# LINE 1 "<command-line>" #-}
{-# LINE 8 "<command-line>" #-}
# 1 "/usr/include/stdc-predef.h" 1 3 4

# 17 "/usr/include/stdc-predef.h" 3 4














































{-# LINE 8 "<command-line>" #-}
{-# LINE 1 "/usr/lib/ghc/include/ghcversion.h" #-}

















{-# LINE 8 "<command-line>" #-}
{-# LINE 1 "/tmp/ghc8814_0/ghc_2.h" #-}




























































































































































{-# LINE 8 "<command-line>" #-}
{-# LINE 1 "templates/GenericTemplate.hs" #-}
-- Id: GenericTemplate.hs,v 1.26 2005/01/14 14:47:22 simonmar Exp 









{-# LINE 43 "templates/GenericTemplate.hs" #-}

data Happy_IntList = HappyCons Int Happy_IntList







{-# LINE 65 "templates/GenericTemplate.hs" #-}

{-# LINE 75 "templates/GenericTemplate.hs" #-}

{-# LINE 84 "templates/GenericTemplate.hs" #-}

infixr 9 `HappyStk`
data HappyStk a = HappyStk a (HappyStk a)

-----------------------------------------------------------------------------
-- starting the parse

happyParse start_state = happyNewToken start_state notHappyAtAll notHappyAtAll

-----------------------------------------------------------------------------
-- Accepting the parse

-- If the current token is (1), it means we've just accepted a partial
-- parse (a %partial parser).  We must ignore the saved token on the top of
-- the stack in this case.
happyAccept (1) tk st sts (_ `HappyStk` ans `HappyStk` _) =
        happyReturn1 ans
happyAccept j tk st sts (HappyStk ans _) = 
         (happyReturn1 ans)

-----------------------------------------------------------------------------
-- Arrays only: do the next action

{-# LINE 137 "templates/GenericTemplate.hs" #-}

{-# LINE 147 "templates/GenericTemplate.hs" #-}
indexShortOffAddr arr off = arr Happy_Data_Array.! off


{-# INLINE happyLt #-}
happyLt x y = (x < y)






readArrayBit arr bit =
    Bits.testBit (indexShortOffAddr arr (bit `div` 16)) (bit `mod` 16)






-----------------------------------------------------------------------------
-- HappyState data type (not arrays)



newtype HappyState b c = HappyState
        (Int ->                    -- token number
         Int ->                    -- token number (yes, again)
         b ->                           -- token semantic value
         HappyState b c ->              -- current state
         [HappyState b c] ->            -- state stack
         c)



-----------------------------------------------------------------------------
-- Shifting a token

happyShift new_state (1) tk st sts stk@(x `HappyStk` _) =
     let i = (case x of { HappyErrorToken (i) -> i }) in
--     trace "shifting the error token" $
     new_state i i tk (HappyState (new_state)) ((st):(sts)) (stk)

happyShift new_state i tk st sts stk =
     happyNewToken new_state ((st):(sts)) ((HappyTerminal (tk))`HappyStk`stk)

-- happyReduce is specialised for the common cases.

happySpecReduce_0 i fn (1) tk st sts stk
     = happyFail [] (1) tk st sts stk
happySpecReduce_0 nt fn j tk st@((HappyState (action))) sts stk
     = action nt j tk st ((st):(sts)) (fn `HappyStk` stk)

happySpecReduce_1 i fn (1) tk st sts stk
     = happyFail [] (1) tk st sts stk
happySpecReduce_1 nt fn j tk _ sts@(((st@(HappyState (action))):(_))) (v1`HappyStk`stk')
     = let r = fn v1 in
       happySeq r (action nt j tk st sts (r `HappyStk` stk'))

happySpecReduce_2 i fn (1) tk st sts stk
     = happyFail [] (1) tk st sts stk
happySpecReduce_2 nt fn j tk _ ((_):(sts@(((st@(HappyState (action))):(_))))) (v1`HappyStk`v2`HappyStk`stk')
     = let r = fn v1 v2 in
       happySeq r (action nt j tk st sts (r `HappyStk` stk'))

happySpecReduce_3 i fn (1) tk st sts stk
     = happyFail [] (1) tk st sts stk
happySpecReduce_3 nt fn j tk _ ((_):(((_):(sts@(((st@(HappyState (action))):(_))))))) (v1`HappyStk`v2`HappyStk`v3`HappyStk`stk')
     = let r = fn v1 v2 v3 in
       happySeq r (action nt j tk st sts (r `HappyStk` stk'))

happyReduce k i fn (1) tk st sts stk
     = happyFail [] (1) tk st sts stk
happyReduce k nt fn j tk st sts stk
     = case happyDrop (k - ((1) :: Int)) sts of
         sts1@(((st1@(HappyState (action))):(_))) ->
                let r = fn stk in  -- it doesn't hurt to always seq here...
                happyDoSeq r (action nt j tk st1 sts1 r)

happyMonadReduce k nt fn (1) tk st sts stk
     = happyFail [] (1) tk st sts stk
happyMonadReduce k nt fn j tk st sts stk =
      case happyDrop k ((st):(sts)) of
        sts1@(((st1@(HappyState (action))):(_))) ->
          let drop_stk = happyDropStk k stk in
          happyThen1 (fn stk tk) (\r -> action nt j tk st1 sts1 (r `HappyStk` drop_stk))

happyMonad2Reduce k nt fn (1) tk st sts stk
     = happyFail [] (1) tk st sts stk
happyMonad2Reduce k nt fn j tk st sts stk =
      case happyDrop k ((st):(sts)) of
        sts1@(((st1@(HappyState (action))):(_))) ->
         let drop_stk = happyDropStk k stk





             _ = nt :: Int
             new_state = action

          in
          happyThen1 (fn stk tk) (\r -> happyNewToken new_state sts1 (r `HappyStk` drop_stk))

happyDrop (0) l = l
happyDrop n ((_):(t)) = happyDrop (n - ((1) :: Int)) t

happyDropStk (0) l = l
happyDropStk n (x `HappyStk` xs) = happyDropStk (n - ((1)::Int)) xs

-----------------------------------------------------------------------------
-- Moving to a new state after a reduction

{-# LINE 267 "templates/GenericTemplate.hs" #-}
happyGoto action j tk st = action j j tk (HappyState action)


-----------------------------------------------------------------------------
-- Error recovery ((1) is the error token)

-- parse error if we are in recovery and we fail again
happyFail explist (1) tk old_st _ stk@(x `HappyStk` _) =
     let i = (case x of { HappyErrorToken (i) -> i }) in
--      trace "failing" $ 
        happyError_ explist i tk

{-  We don't need state discarding for our restricted implementation of
    "error".  In fact, it can cause some bogus parses, so I've disabled it
    for now --SDM

-- discard a state
happyFail  (1) tk old_st (((HappyState (action))):(sts)) 
                                                (saved_tok `HappyStk` _ `HappyStk` stk) =
--      trace ("discarding state, depth " ++ show (length stk))  $
        action (1) (1) tk (HappyState (action)) sts ((saved_tok`HappyStk`stk))
-}

-- Enter error recovery: generate an error token,
--                       save the old token and carry on.
happyFail explist i tk (HappyState (action)) sts stk =
--      trace "entering error recovery" $
        action (1) (1) tk (HappyState (action)) sts ( (HappyErrorToken (i)) `HappyStk` stk)

-- Internal happy errors:

notHappyAtAll :: a
notHappyAtAll = error "Internal Happy error\n"

-----------------------------------------------------------------------------
-- Hack to get the typechecker to accept our action functions







-----------------------------------------------------------------------------
-- Seq-ing.  If the --strict flag is given, then Happy emits 
--      happySeq = happyDoSeq
-- otherwise it emits
--      happySeq = happyDontSeq

happyDoSeq, happyDontSeq :: a -> b -> b
happyDoSeq   a b = a `seq` b
happyDontSeq a b = b

-----------------------------------------------------------------------------
-- Don't inline any functions from the template.  GHC has a nasty habit
-- of deciding to inline happyGoto everywhere, which increases the size of
-- the generated parser quite a bit.

{-# LINE 333 "templates/GenericTemplate.hs" #-}
{-# NOINLINE happyShift #-}
{-# NOINLINE happySpecReduce_0 #-}
{-# NOINLINE happySpecReduce_1 #-}
{-# NOINLINE happySpecReduce_2 #-}
{-# NOINLINE happySpecReduce_3 #-}
{-# NOINLINE happyReduce #-}
{-# NOINLINE happyMonadReduce #-}
{-# NOINLINE happyGoto #-}
{-# NOINLINE happyFail #-}

-- end of Happy Template.
