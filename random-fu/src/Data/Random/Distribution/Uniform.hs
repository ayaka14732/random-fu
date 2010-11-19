{-
 -      ``Data/Random/Distribution/Uniform''
 -}
{-# LANGUAGE
    MultiParamTypeClasses, FunctionalDependencies,
    FlexibleContexts, FlexibleInstances, 
    UndecidableInstances, EmptyDataDecls,
    TemplateHaskell,
    BangPatterns
  #-}

module Data.Random.Distribution.Uniform
    ( Uniform(..)
	, uniform
	, uniformT
	
    , StdUniform(..)
    , stdUniform
    , stdUniformT
    , stdUniformPos
    , stdUniformPosT
    
    , integralUniform
    , realFloatUniform
    , floatUniform
    , doubleUniform
    , fixedUniform
    
    , boundedStdUniform
    , boundedEnumStdUniform
    , realFloatStdUniform
    , fixedStdUniform
    , floatStdUniform
    , doubleStdUniform
    
    , realStdUniformCDF
    , realUniformCDF
    ) where

import Data.Random.Internal.TH
import Data.Random.Internal.Words
import Data.Random.Internal.Fixed

import Data.Random.Source
import Data.Random.Distribution
import Data.Random.RVar

import Data.Fixed
import Data.Word
import Data.Int
import Data.List

import Control.Monad.Loops

-- |Compute a random 'Integral' value between the 2 values provided (inclusive).
{-# INLINE integralUniform #-}
integralUniform :: (Integral a) => a -> a -> RVarT m a
integralUniform !x !y = if x < y then integralUniform' x y else integralUniform' y x

{-# SPECIALIZE integralUniform' :: Int     -> Int     -> RVarT m Int   #-}
{-# SPECIALIZE integralUniform' :: Int8    -> Int8    -> RVarT m Int8  #-}
{-# SPECIALIZE integralUniform' :: Int16   -> Int16   -> RVarT m Int16 #-}
{-# SPECIALIZE integralUniform' :: Int32   -> Int32   -> RVarT m Int32 #-}
{-# SPECIALIZE integralUniform' :: Int64   -> Int64   -> RVarT m Int64 #-}
{-# SPECIALIZE integralUniform' :: Word    -> Word    -> RVarT m Word   #-}
{-# SPECIALIZE integralUniform' :: Word8   -> Word8   -> RVarT m Word8  #-}
{-# SPECIALIZE integralUniform' :: Word16  -> Word16  -> RVarT m Word16 #-}
{-# SPECIALIZE integralUniform' :: Word32  -> Word32  -> RVarT m Word32 #-}
{-# SPECIALIZE integralUniform' :: Word64  -> Word64  -> RVarT m Word64 #-}
{-# SPECIALIZE integralUniform' :: Integer -> Integer -> RVarT m Integer #-}
integralUniform' :: (Integral a) => a -> a -> RVarT m a
integralUniform' !l !u
    | nReject == 0  = fmap shift prim
    | otherwise     = fmap shift loop
    where
        m = 1 + toInteger u - toInteger l
        (bytes, nPossible) = bytesNeeded m
        nReject = nPossible `mod` m
        
        !prim = getRandomPrim (PrimNByteInteger bytes)
        !shift = \(!z) -> l + (fromInteger $! (z `mod` m))
        
        loop = do
            z <- prim
            if z < nReject
                then loop
                else return z

integralUniformCDF :: (Integral a, Fractional b) => a -> a -> a -> b
integralUniformCDF a b x
    | b < a     = integralUniformCDF b a x
    | x < a     = 0
    | x > b     = 1
    | otherwise = (fromIntegral x - fromIntegral a) / (fromIntegral b - fromIntegral a)

-- TODO: come up with a decent, fast heuristic to decide whether to return an extra
-- byte.  May involve moving calculation of nReject into this function, and then
-- accepting first if 4*nReject < nPossible or something similar.
bytesNeeded :: Integer -> (Int, Integer)
bytesNeeded x = head (dropWhile ((<= x).snd) powersOf256)

powersOf256 :: [(Int, Integer)]
powersOf256 = zip [0..] (iterate (256 *) 1)

-- |Compute a random value for a 'Bounded' type, between 'minBound' and 'maxBound'
-- (inclusive for 'Integral' or 'Enum' types, in ['minBound', 'maxBound') for Fractional types.)
boundedStdUniform :: (Distribution Uniform a, Bounded a) => RVar a
boundedStdUniform = uniform minBound maxBound

boundedStdUniformCDF :: (CDF Uniform a, Bounded a) => a -> Double
boundedStdUniformCDF = cdf (Uniform minBound maxBound)

-- |Compute a random value for a 'Bounded' 'Enum' type, between 'minBound' and
-- 'maxBound' (inclusive)
boundedEnumStdUniform :: (Enum a, Bounded a) => RVarT m a
boundedEnumStdUniform = enumUniform minBound maxBound

boundedEnumStdUniformCDF :: (Enum a, Bounded a, Ord a) => a -> Double
boundedEnumStdUniformCDF = enumUniformCDF minBound maxBound

-- |Compute a uniform random 'Float' value in the range [0,1)
floatStdUniform :: RVarT m Float
floatStdUniform = do
    x <- getRandomPrim PrimWord32
    return (word32ToFloat x)

-- |Compute a uniform random 'Double' value in the range [0,1)
{-# INLINE doubleStdUniform #-}
doubleStdUniform :: RVarT m Double
doubleStdUniform = getRandomPrim PrimDouble

-- |Compute a uniform random value in the range [0,1) for any 'RealFloat' type 
realFloatStdUniform :: RealFloat a => RVarT m a
realFloatStdUniform = do
    let (b, e) = decodeFloat one
    
    x <- uniformT 0 (b-1)
    if x == 0
        then return (0 `asTypeOf` one)
        else return (encodeFloat x e)
    
    where one = 1

-- |Compute a uniform random 'Fixed' value in the range [0,1), with any
-- desired precision.
fixedStdUniform :: HasResolution r => RVarT m (Fixed r)
fixedStdUniform = x
    where
        res = resolutionOf2 x
        x = do
            u <- uniformT 0 (res)
            return (mkFixed u)

-- |The CDF of the random variable 'realFloatStdUniform'.
realStdUniformCDF :: Real a => a -> Double
realStdUniformCDF x
    | x <= 0    = 0
    | x >= 1    = 1
    | otherwise = realToFrac x

-- |@floatUniform a b@ computes a uniform random 'Float' value in the range [a,b)
floatUniform :: Float -> Float -> RVarT m Float
floatUniform 0 1 = floatStdUniform
floatUniform a b = do
    x <- floatStdUniform
    return (a*(1-x)*a + b*x)

-- |@doubleUniform a b@ computes a uniform random 'Double' value in the range [a,b)
{-# INLINE doubleUniform #-}
doubleUniform :: Double -> Double -> RVarT m Double
doubleUniform 0 1 = doubleStdUniform
doubleUniform a b = do
    x <- doubleStdUniform
    return (a*(1-x)*a + b*x)

-- |@realFloatUniform a b@ computes a uniform random value in the range [a,b) for
-- any 'RealFloat' type
realFloatUniform :: RealFloat a => a -> a -> RVarT m a
realFloatUniform 0 1 = realFloatStdUniform
realFloatUniform a b = do
    x <- realFloatStdUniform
    return (a*(1-x)*a + b*x)

-- |@fixedUniform a b@ computes a uniform random 'Fixed' value in the range 
-- [a,b), with any desired precision.
fixedUniform :: HasResolution r => Fixed r -> Fixed r -> RVarT m (Fixed r)
fixedUniform a b = do
    u <- integralUniform (unMkFixed a) (unMkFixed b)
    return (mkFixed u)

-- |@realUniformCDF a b@ is the CDF of the random variable @realFloatUniform a b@.
realUniformCDF :: RealFrac a => a -> a -> a -> Double
realUniformCDF a b x
    | b < a     = realUniformCDF b a x
    | x <= a    = 0
    | x >= b    = 1
    | otherwise = realToFrac ((x-a) / (b-a))

-- |@realFloatUniform a b@ computes a uniform random value in the range [a,b) for
-- any 'Enum' type
enumUniform :: Enum a => a -> a -> RVarT m a
enumUniform a b = do
    x <- integralUniform (fromEnum a) (fromEnum b)
    return (toEnum x)

enumUniformCDF :: (Enum a, Ord a) => a -> a -> a -> Double
enumUniformCDF a b x
    | b < a     = enumUniformCDF b a x
    | x <= a    = 0
    | x >= b    = 1
    | otherwise = (e2f x - e2f a) / (e2f b - e2f a)
    
    where e2f = fromIntegral . fromEnum

-- @uniform a b@ is a uniformly distributed random variable in the range
-- [a,b] for 'Integral' or 'Enum' types and in the range [a,b) for 'Fractional'
-- types.  Requires a @Distribution Uniform@ instance for the type.
uniform :: Distribution Uniform a => a -> a -> RVar a
uniform a b = rvar (Uniform a b)

-- @uniformT a b@ is a uniformly distributed random process in the range
-- [a,b] for 'Integral' or 'Enum' types and in the range [a,b) for 'Fractional'
-- types.  Requires a @Distribution Uniform@ instance for the type.
uniformT :: Distribution Uniform a => a -> a -> RVarT m a
uniformT a b = rvarT (Uniform a b)

-- |Get a \"standard\" uniformly distributed variable.
-- For integral types, this means uniformly distributed over the full range
-- of the type (there is no support for 'Integer').  For fractional
-- types, this means uniformly distributed on the interval [0,1).
{-# SPECIALIZE stdUniform :: RVar Double #-}
{-# SPECIALIZE stdUniform :: RVar Float #-}
stdUniform :: (Distribution StdUniform a) => RVar a
stdUniform = rvar StdUniform

-- |Get a \"standard\" uniformly distributed process.
-- For integral types, this means uniformly distributed over the full range
-- of the type (there is no support for 'Integer').  For fractional
-- types, this means uniformly distributed on the interval [0,1).
{-# SPECIALIZE stdUniformT :: RVarT m Double #-}
{-# SPECIALIZE stdUniformT :: RVarT m Float #-}
stdUniformT :: (Distribution StdUniform a) => RVarT m a
stdUniformT = rvarT StdUniform

-- |Like 'stdUniform', but returns only positive or zero values.  Not 
-- exported because it is not truly uniform: nonzero values are twice
-- as likely as zero on signed types.
stdUniformNonneg :: (Distribution StdUniform a, Num a) => RVarT m a
stdUniformNonneg = fmap abs stdUniformT

-- |Like 'stdUniform' but only returns positive values.
stdUniformPos :: (Distribution StdUniform a, Num a) => RVar a
stdUniformPos = stdUniformPosT

-- |Like 'stdUniform' but only returns positive values.
stdUniformPosT :: (Distribution StdUniform a, Num a) => RVarT m a
stdUniformPosT = iterateUntil (/= 0) stdUniformNonneg

-- |A definition of a uniform distribution over the type @t@.  See also 'uniform'.
data Uniform t = 
    -- |A uniform distribution defined by a lower and upper range bound.
    -- For 'Integral' and 'Enum' types, the range is inclusive.  For 'Fractional'
    -- types the range includes the lower bound but not the upper.
    Uniform !t !t

-- |A name for the \"standard\" uniform distribution over the type @t@,
-- if one exists.  See also 'stdUniform'.
--
-- For 'Integral' and 'Enum' types that are also 'Bounded', this is
-- the uniform distribution over the full range of the type.
-- For un-'Bounded' 'Integral' types this is not defined.
-- For 'Fractional' types this is a random variable in the range [0,1)
-- (that is, 0 to 1 including 0 but not including 1).
data StdUniform t = StdUniform

$( replicateInstances ''Int integralTypes [d|
        instance Distribution Uniform Int   where rvarT (Uniform a b) = integralUniform a b
        instance CDF Uniform Int            where cdf   (Uniform a b) = integralUniformCDF a b
    |])

instance Distribution StdUniform Word8      where rvarT ~StdUniform = getRandomPrim PrimWord8
instance Distribution StdUniform Word16     where rvarT ~StdUniform = getRandomPrim PrimWord16
instance Distribution StdUniform Word32     where rvarT ~StdUniform = getRandomPrim PrimWord32
instance Distribution StdUniform Word64     where rvarT ~StdUniform = getRandomPrim PrimWord64

instance Distribution StdUniform Int8       where rvarT ~StdUniform = fromIntegral `fmap` getRandomPrim PrimWord8
instance Distribution StdUniform Int16      where rvarT ~StdUniform = fromIntegral `fmap` getRandomPrim PrimWord16
instance Distribution StdUniform Int32      where rvarT ~StdUniform = fromIntegral `fmap` getRandomPrim PrimWord32
instance Distribution StdUniform Int64      where rvarT ~StdUniform = fromIntegral `fmap` getRandomPrim PrimWord64

instance Distribution StdUniform Int where
    rvar ~StdUniform =
        $(if toInteger (maxBound :: Int) > toInteger (maxBound :: Int32)
            then [|fromIntegral `fmap` getRandomPrim PrimWord64|]
            else [|fromIntegral `fmap` getRandomPrim PrimWord32|])

instance Distribution StdUniform Word where
    rvar ~StdUniform =
        $(if toInteger (maxBound :: Word) > toInteger (maxBound :: Word32)
            then [|fromIntegral `fmap` getRandomPrim PrimWord64|]
            else [|fromIntegral `fmap` getRandomPrim PrimWord32|])

-- Integer has no StdUniform...

$( replicateInstances ''Int (integralTypes \\ [''Integer]) [d|
        instance CDF StdUniform Int         where cdf  ~StdUniform = boundedStdUniformCDF
    |])


instance Distribution Uniform Float         where rvarT (Uniform a b) = floatUniform  a b
instance Distribution Uniform Double        where rvarT (Uniform a b) = doubleUniform a b
instance CDF Uniform Float                  where cdf   (Uniform a b) = realUniformCDF a b
instance CDF Uniform Double                 where cdf   (Uniform a b) = realUniformCDF a b

instance Distribution StdUniform Float      where rvarT ~StdUniform = floatStdUniform
instance Distribution StdUniform Double     where rvarT ~StdUniform = getRandomPrim PrimDouble; rvarT ~StdUniform = getRandomPrim PrimDouble
instance CDF StdUniform Float               where cdf   ~StdUniform = realStdUniformCDF
instance CDF StdUniform Double              where cdf   ~StdUniform = realStdUniformCDF

instance HasResolution r => 
         Distribution Uniform (Fixed r)     where rvarT (Uniform a b) = fixedUniform  a b
instance HasResolution r => 
         CDF Uniform (Fixed r)              where cdf   (Uniform a b) = realUniformCDF a b
instance HasResolution r =>
         Distribution StdUniform (Fixed r)  where rvarT ~StdUniform = fixedStdUniform
instance HasResolution r => 
         CDF StdUniform (Fixed r)           where cdf   ~StdUniform = realStdUniformCDF

instance Distribution Uniform ()            where rvarT (Uniform _ _) = return ()
instance CDF Uniform ()                     where cdf   (Uniform _ _) = return 1
$( replicateInstances ''Char [''Char, ''Bool, ''Ordering] [d|
        instance Distribution Uniform Char  where rvarT (Uniform a b) = enumUniform a b
        instance CDF Uniform Char           where cdf   (Uniform a b) = enumUniformCDF a b

    |])

instance Distribution StdUniform ()         where rvarT ~StdUniform = return ()
instance CDF StdUniform ()                  where cdf   ~StdUniform = return 1
instance Distribution StdUniform Bool       where rvarT ~StdUniform = fmap even (getRandomPrim PrimWord8)
instance CDF StdUniform Bool                where cdf   ~StdUniform = boundedEnumStdUniformCDF

instance Distribution StdUniform Char       where rvarT ~StdUniform = boundedEnumStdUniform
instance CDF StdUniform Char                where cdf   ~StdUniform = boundedEnumStdUniformCDF
instance Distribution StdUniform Ordering   where rvarT ~StdUniform = boundedEnumStdUniform
instance CDF StdUniform Ordering            where cdf   ~StdUniform = boundedEnumStdUniformCDF
