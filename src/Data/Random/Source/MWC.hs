{-# LANGUAGE
        MultiParamTypeClasses,
        FlexibleInstances,
        GADTs
  #-}
module Data.Random.Source.MWC where

import Data.Random.Internal.Primitives
import Data.Random.Internal.Words
import Data.Random.Source
import System.Random.MWC
import Control.Monad.ST

instance RandomSource (ST s) (Gen s) where
    {-# INLINE supportedPrimsFrom #-}
    supportedPrimsFrom _ PrimWord8  = True
--    supportedPrimsFrom _ PrimWord32 = True
    supportedPrimsFrom _ PrimWord64 = True
    supportedPrimsFrom _ PrimDouble = True
    supportedPrimsFrom _ _ = False
    
    {-# INLINE getSupportedRandomPrimFrom #-}
    getSupportedRandomPrimFrom gen PrimWord8    = uniform gen
    getSupportedRandomPrimFrom gen PrimWord32   = uniform gen
    getSupportedRandomPrimFrom gen PrimWord64   = uniform gen
    getSupportedRandomPrimFrom gen PrimDouble   = fmap wordToDouble (uniform gen)

instance RandomSource IO (Gen RealWorld) where
    {-# INLINE supportedPrimsFrom #-}
    supportedPrimsFrom _ PrimWord8  = True
--    supportedPrimsFrom _ PrimWord32 = True
    supportedPrimsFrom _ PrimWord64 = True
    supportedPrimsFrom _ PrimDouble = True
    supportedPrimsFrom _ _ = False
    
    {-# INLINE getSupportedRandomPrimFrom #-}
    getSupportedRandomPrimFrom gen prim = stToIO (getSupportedRandomPrimFrom gen prim)