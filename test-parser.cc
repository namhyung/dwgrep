#include <string>
#include <iostream>
#include <memory>
#include <sstream>

#include "tree.hh"
#include "parser.hh"
#include "lexer.hh"
#include "known-dwarf.h"

static unsigned tests = 0, failed = 0;
void
test (std::string parse, std::string expect)
{
  ++tests;
  yy_scan_string (parse.c_str ());
  std::unique_ptr <tree> t;
  if (yyparse (t) == 0)
    {
      std::ostringstream ss;
      t->dump (ss);
      if (ss.str () != expect)
	{
	  std::cerr << "bad parse: «" << parse << "»" << std::endl;
	  std::cerr << "   result: «" << ss.str () << "»" << std::endl;
	  std::cerr << "   expect: «" << expect << "»" << std::endl;
	  ++failed;
	}
    }
  else
    {
      std::cerr << "can't parse: «" << parse << "»" << std::endl;
      ++failed;
    }
}

int
main (int argc, char *argv[])
{
#define ONE_KNOWN_DW_TAG(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_TAG;
#undef ONE_KNOWN_DW_TAG

#define ONE_KNOWN_DW_AT(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_AT;
#undef ONE_KNOWN_DW_AT

#define ONE_KNOWN_DW_FORM_DESC(NAME, CODE, DESC) ONE_KNOWN_DW_FORM (NAME, CODE)
#define ONE_KNOWN_DW_FORM(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_FORM;
#undef ONE_KNOWN_DW_FORM
#undef ONE_KNOWN_DW_FORM_DESC

#define ONE_KNOWN_DW_LANG_DESC(NAME, CODE, DESC)	\
	test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_LANG;
#undef ONE_KNOWN_DW_LANG_DESC

#define ONE_KNOWN_DW_INL(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_INL;
#undef ONE_KNOWN_DW_INL

#define ONE_KNOWN_DW_ATE(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_ATE;
#undef ONE_KNOWN_DW_ATE

#define ONE_KNOWN_DW_ACCESS(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_ACCESS;
#undef ONE_KNOWN_DW_ACCESS

#define ONE_KNOWN_DW_VIS(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_VIS;
#undef ONE_KNOWN_DW_VIS

#define ONE_KNOWN_DW_VIRTUALITY(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_VIRTUALITY;
#undef ONE_KNOWN_DW_VIRTUALITY

#define ONE_KNOWN_DW_ID(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_ID;
#undef ONE_KNOWN_DW_ID

#define ONE_KNOWN_DW_CC(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_CC;
#undef ONE_KNOWN_DW_CC

#define ONE_KNOWN_DW_ORD(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_ORD;
#undef ONE_KNOWN_DW_ORD

#define ONE_KNOWN_DW_DSC(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_DSC;
#undef ONE_KNOWN_DW_DSC

#define ONE_KNOWN_DW_OP_DESC(NAME, CODE, DESC) ONE_KNOWN_DW_OP (NAME, CODE)
#define ONE_KNOWN_DW_OP(NAME, CODE) test (#CODE, "(CONST<" #CODE ">)");
  ALL_KNOWN_DW_OP;
#undef ONE_KNOWN_DW_OP
#undef ONE_KNOWN_DW_OP_DESC

  test ("17", "(CONST<17>)");
  test ("0x17", "(CONST<23>)");
  test ("017", "(CONST<15>)");

  test ("\"string\"", "(STR<\"string\">)");

  test ("swap", "(SHF_SWAP)");
  test ("dup", "(SHF_DUP)");
  test ("over", "(SHF_OVER)");
  test ("rot", "(SHF_ROT)");
  test ("drop", "(SHF_DROP)");
  test ("if", "(PIPE (ASSERT (PRED_NOT (PRED_EMPTY))) (SHF_DROP))");
  test ("else", "(PIPE (ASSERT (PRED_EMPTY)) (SHF_DROP))");

  test ("?eq", "(ASSERT (PRED_EQ))");
  test ("!eq", "(ASSERT (PRED_NOT (PRED_EQ)))");
  test ("?ne", "(ASSERT (PRED_NE))");
  test ("!ne", "(ASSERT (PRED_NOT (PRED_NE)))");
  test ("?lt", "(ASSERT (PRED_LT))");
  test ("!lt", "(ASSERT (PRED_NOT (PRED_LT)))");
  test ("?gt", "(ASSERT (PRED_GT))");
  test ("!gt", "(ASSERT (PRED_NOT (PRED_GT)))");
  test ("?le", "(ASSERT (PRED_LE))");
  test ("!le", "(ASSERT (PRED_NOT (PRED_LE)))");
  test ("?ge", "(ASSERT (PRED_GE))");
  test ("!ge", "(ASSERT (PRED_NOT (PRED_GE)))");

  test ("?match", "(ASSERT (PRED_MATCH))");
  test ("!match", "(ASSERT (PRED_NOT (PRED_MATCH)))");
  test ("?find", "(ASSERT (PRED_FIND))");
  test ("!find", "(ASSERT (PRED_NOT (PRED_FIND)))");

  test ("?root", "(ASSERT (PRED_ROOT))");
  test ("!root", "(ASSERT (PRED_NOT (PRED_ROOT)))");

  test ("add", "(F_ADD)");
  test ("sub", "(F_SUB)");
  test ("mul", "(F_MUL)");
  test ("div", "(F_DIV)");
  test ("mod", "(F_MOD)");
  test ("parent", "(F_PARENT)");
  test ("child", "(F_CHILD)");
  test ("attribute", "(F_ATTRIBUTE)");
  test ("prev", "(F_PREV)");
  test ("next", "(F_NEXT)");
  test ("type", "(F_TYPE)");
  test ("offset", "(F_OFFSET)");
  test ("name", "(F_NAME)");
  test ("tag", "(F_TAG)");
  test ("form", "(F_FORM)");
  test ("value", "(F_VALUE)");
  test ("pos", "(F_POS)");
  test ("count", "(F_COUNT)");
  test ("each", "(EACH)");

  test ("+add", "(NODROP (F_ADD))");
  test ("+sub", "(NODROP (F_SUB))");
  test ("+mul", "(NODROP (F_MUL))");
  test ("+div", "(NODROP (F_DIV))");
  test ("+mod", "(NODROP (F_MOD))");
  test ("+parent", "(NODROP (F_PARENT))");
  test ("+child", "(NODROP (F_CHILD))");
  test ("+attribute", "(NODROP (F_ATTRIBUTE))");
  test ("+prev", "(NODROP (F_PREV))");
  test ("+next", "(NODROP (F_NEXT))");
  test ("+type", "(NODROP (F_TYPE))");
  test ("+offset", "(NODROP (F_OFFSET))");
  test ("+name", "(NODROP (F_NAME))");
  test ("+tag", "(NODROP (F_TAG))");
  test ("+form", "(NODROP (F_FORM))");
  test ("+value", "(NODROP (F_VALUE))");
  test ("+pos", "(NODROP (F_POS))");
  test ("+count", "(NODROP (F_COUNT))");
  test ("+each", "(NODROP (EACH))");

#define ONE_KNOWN_DW_AT(NAME, CODE)				\
  test ("@"#NAME, "(ATVAL<" #CODE ">)");			\
  test ("+@"#NAME, "(NODROP (ATVAL<" #CODE ">))");		\
  test ("?@"#NAME, "(ASSERT (PRED_AT<" #CODE ">))");		\
  test ("!@"#NAME, "(ASSERT (PRED_NOT (PRED_AT<" #CODE ">)))");

  ALL_KNOWN_DW_AT;
#undef ONE_KNOWN_DW_AT

#define ONE_KNOWN_DW_TAG(NAME, CODE)				\
  test ("?"#NAME, "(ASSERT (PRED_TAG<" #CODE ">))");		\
  test ("!"#NAME, "(ASSERT (PRED_NOT (PRED_TAG<" #CODE ">)))");

  ALL_KNOWN_DW_TAG;
#undef ONE_KNOWN_DW_TAG

  std::cerr << tests << " tests total, " << failed << " failures.\n";

  if (argc > 1)
    {
      yy_scan_string (argv[1]);
      std::unique_ptr <tree> t;
      if (yyparse (t) == 0)
	{
	  t->dump (std::cerr);
	  std::cerr << std::endl;
	}
    }

  return 0;
}
