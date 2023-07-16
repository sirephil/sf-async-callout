/*
 * MIT License. See the associated LICENSE file.
 * 
 * Copyright sirephil (c) 2023.
 */

/**
 * This class serves as a flyweight factory for dependency injection, allowing tests to mock supported classes
 * with a minimum of fuss.
 *
 * <p>The assumption is that all classes to be mocked use no-arg constructions and that dependency injection is always
 * via this factory, throughout the entire code base. If class A needs an instance of class B, the class B instance is
 * obtained through the factory. If class B then needs an instance of class C, this isn't passed to B but is instead
 * again obtained through this factory.</p>
 */
public without sharing class SingletonFactory {
    /**
     * Instructions for creating an instance of a singleton.
     */
    private class Blueprint {
        /**
         * The Type of the singleton produced by this blueprint.
         */
        public Type instanceType;

        /**
         * Specifies a stub provider to be used for singleton creation.
         */
        public StubProvider stubProvider;

        /**
         * Initialises the new instance using the given parameters.
         *
         * @param instanceType The Type of the singleton produced by this blueprint.
         */
        public Blueprint(Type instanceType) {
            this.instanceType = instanceType;
        }
    }

    /**
     * Holds all cacheable data relevant to a given Type.
     */
    private class CacheItem {
        /**
         * The singleton instance created for the given Type.
         */
        public Object instance;

        /**
         * The optional blueprints for customising singleton creation.
         */
        public Blueprint blueprint;

        /**
         * Initialises the new instance using the given parameters.
         *
         * @param instanceType The Type for which this cache item is being created. Must not be null.
         */
        public CacheItem(Type instanceType) {
            this.blueprint = new Blueprint(instanceType);
        }
    }

    /**
     * Holds the cache of any instances which have already been created as well as any creation parameter which
     * have been specified, mapped to the Type for which they are to be used.
     */
    private static Map<Type, CacheItem> cache = new Map<Type, CacheItem>();

    /**
     * Returns the singleton instance which has been configured to be used for the given class Type.
     * If no instance already exists then a new instance of the specified class Type will be created, using any
     * custom blueprints which were previously provided for this Type.
     *
     * @param instanceType The Type for which to retrieve the singleton instance. Must not be null.
     *
     * @return The singleton instance configured for this Type. Will not be null.
     */
    public static Object get(Type instanceType) {
        CacheItem cachedItem = readCache(instanceType);

        if (cachedItem.instance == null) {
            cachedItem.instance = createInstance(cachedItem.blueprint);
        }

        return cachedItem.instance;
    }

    /**
     * Creates and returns an instance of the given class type (or the configured override type) independent of
     * the internal cache, bypassing the singleton pattern.
     *
     * @param instanceType The type for which to create a new instance. Must not be null.
     *
     * @return A new instance of the given Type, or the configured mock. Will not be null.
     */
    public static Object getStandaloneInstance(Type instanceType) {
        return createInstance(readCache(instanceType).blueprint);
    }

    /**
     * Instantiates a class using the provided blueprint.
     *
     * @param blueprint The blueprint from which to create a class instance. Must not be null.
     *
     * @return The new class instance. Will not be null.
     */
    private static Object createInstance(Blueprint blueprint) {
        if (blueprint.stubProvider != null) {
            return (Object) Test.createStub(blueprint.instanceType, blueprint.stubProvider);
        } else {
            return (Object) blueprint.instanceType.newInstance();
        }
    }

    /**
     * Gets an item from the cache, first creating it if necessary.
     *
     * @param instanceType The Type which is the key of the cached item. Must not be null.
     *
     * @return The cache object for the specified key. Will not be null.
     */
    private static CacheItem readCache(Type instanceType) {
        CacheItem result = cache.get(instanceType);

        if (result == null) {
            result = new CacheItem(instanceType);
            cache.put(instanceType, result);
        }

        return result;
    }

    /**
     * Specifies the Type of singleton to be created when the given Type is requested.
     *
     * @param actualType	The class Type with which to associate the provided override. Must not be null.
     * @param overrideType	The Type of singleton to return when the specified Type is requested. Must not be null.
     */
    public static void setTypeOverride(Type actualType, Type overrideType) {
        CacheItem cachedItem = readCache(actualType);
        cachedItem.blueprint.instanceType = overrideType;
        cachedItem.instance = null;
    }

    /**
     * Sets the stub provider to be used when creating instances of the specified Type.
     *
     * @param instanceType The class Type with which to associate the provided stub provider. Must not be null.
     * @param stubProvider The stub provider to be used when creating instances of the specified Type. Must not be null.
     */
    public static void setStubProvider(Type instanceType, StubProvider stubProvider) {
        if (Test.isRunningTest()) {
            CacheItem cachedItem = readCache(instanceType);
            cachedItem.blueprint.stubProvider = stubProvider;
            cachedItem.instance =  null;
        }
    }
}