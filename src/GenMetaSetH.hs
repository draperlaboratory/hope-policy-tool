{-
 - Copyright © 2017-2018 The Charles Stark Draper Laboratory, Inc. and/or Dover Microsystems, Inc.
 - All rights reserved.
 -
 - Use and disclosure subject to the following license.
 -
 - Permission is hereby granted, free of charge, to any person obtaining
 - a copy of this software and associated documentation files (the
 - "Software"), to deal in the Software without restriction, including
 - without limitation the rights to use, copy, modify, merge, publish,
 - distribute, sublicense, and/or sell copies of the Software, and to
 - permit persons to whom the Software is furnished to do so, subject to
 - the following conditions:
 -
 - The above copyright notice and this permission notice shall be
 - included in all copies or substantial portions of the Software.
 -
 - THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 - EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 - MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 - NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 - LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 - OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 - WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 -}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE NamedFieldPuns #-}
module GenMetaSetH (writeMetaSetHFile) where

import Language.C.Syntax
import Language.C.Quote.GCC

import GenUtils (renderC)
import Tags (TagInfo(..))

writeMetaSetHFile :: FilePath -> TagInfo -> IO ()
writeMetaSetHFile chFile tinfo =
  writeFile chFile (   tagSetHeader tinfo
                    ++ (renderC tagSetBody) ++ "\n\n"
                    ++ tagSetFooter)

tagSetHeader :: TagInfo -> String
tagSetHeader (TagInfo {tiMaxTag,tiArrayLength,
                       tiNumBitFields,tiNumDataArgs}) = unlines
  ["#ifndef META_SET_H"
  ,"#define META_SET_H"
  ,""
  ,"#include <stdint.h>"
  ,"#include <stdbool.h>"
  ,"#include <stddef.h>"
  ,""
  , "#ifdef __cplusplus"
  , "extern \"C\" {"
  , "#endif"
  ,"// The size of a whole tag set, in uint32s"
  ,"#define META_SET_WORDS " ++ show tiArrayLength
  ,""
  ,"// The number of bitfields in ms->tags"
  ,"#define META_SET_BITFIELDS " ++ show tiNumBitFields
  ,""
  ,"// The number of tag argument postions following the bitfields in ms->tags"
  ,"#define META_SET_ARGS " ++ show tiNumDataArgs
  ,""
  ,"// The maximum tag.  Tags are positions in the 'tags' bitfield."
  ,"#define MAX_TAG " ++ show tiMaxTag
  ,""
  ,"// Actual tag size (while we use 32-bit tags the software validator is 64-bit)"
  ,"#if UINTPTR_MAX == UINT32_MAX"
  ,"#define META_SET_TAG_TYPE uint32_t"
  ,"#elif UINTPTR_MAX == UINT64_MAX"
  ,"#define META_SET_TAG_TYPE uint64_t"
  ,"#endif // UINTPTR_MAX == UINT?_MAX"
  ,""
  ]

tagSetFooter :: String
tagSetFooter = unlines
  [ ""
  , "#ifdef __cplusplus"
  , "}"
  , "#endif"
  ,"#endif"
  ]


tagSetBody :: [Definition]
tagSetBody = [cunit|
  typedef typename intptr_t tag_t;
  typedef typename uintptr_t meta_t;

  typedef struct {
    typename META_SET_TAG_TYPE tags[ META_SET_WORDS ];
  } meta_set_t;

  tag_t canonize(const meta_set_t* ts);
  const meta_set_t* get_ms(tag_t tag);
  typename bool ms_contains(const meta_set_t* ms, meta_t m);
  typename bool ms_eq(const meta_set_t* ms1, const meta_set_t* ms2);
  void ms_bit_add(meta_set_t* ms, meta_t m);
  void ms_bit_remove(meta_set_t* ms, meta_t m);
  int ms_union(meta_set_t* ms1, const meta_set_t* ms2);
|]

