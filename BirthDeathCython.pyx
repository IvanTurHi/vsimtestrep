# cython: language_level=3
# cython: initializedcheck = False
# distutils: language = c++

cimport cython

from libc.math cimport log, floor
from libcpp.vector cimport vector
from mc_lib.rndm cimport RndmWrapper

import numpy as np
np.random.seed(1256)
import sys

include "fast_choose.pxi"


def print_err(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


# use named constants for event types
DEF BIRTH = 0
DEF DEATH = 1
DEF SAMPLING = 2
DEF MUTATION = 3
DEF MIGRATION = 4


cdef class Event:
    cdef:
        double time
        Py_ssize_t type_, population, haplotype, newHaplotype, newPopulation

    def __init__(self, double time, Py_ssize_t type_, Py_ssize_t population, Py_ssize_t haplotype, Py_ssize_t newHaplotype, Py_ssize_t newPopulation):
        self.time = time
        self.type_ = type_
        self.population = population
        self.haplotype = haplotype
        self.newHaplotype = newHaplotype
        self.newPopulation = newPopulation


cdef class Events:
    cdef:
        double[::1] times
        Py_ssize_t size, ptr
        Py_ssize_t[::1] types, populations, haplotypes, newHaplotypes, newPopulations

    def __init__(self, Py_ssize_t size_):
        self.size = size_
        self.ptr = 0#pointer to the first empty cell

        self.times = np.zeros(self.size, dtype=float)
        self.types = np.zeros(self.size, dtype=int)
        self.populations = np.zeros(self.size, dtype=int)
        self.haplotypes = np.zeros(self.size, dtype=int)
        self.newHaplotypes = np.zeros(self.size, dtype=int)
        self.newPopulations = np.zeros(self.size, dtype=int)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void AddEvent(self, double time_, Py_ssize_t type_, Py_ssize_t population, Py_ssize_t haplotype, Py_ssize_t newHaplotype, Py_ssize_t newPopulation):
        self.times[ self.ptr ] = time_
        self.types[ self.ptr ] = type_
        self.populations[ self.ptr ] = population
        self.haplotypes[ self.ptr ] = haplotype
        self.newHaplotypes[ self.ptr ] = newHaplotype
        self.newPopulations[ self.ptr ] = newPopulation
        self.ptr += 1

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef Event GetEvent(self, Py_ssize_t e_id):
        ev = Event( self.times[ e_id ], self.types[ e_id ], self.populations[ e_id ], self.haplotypes[ e_id ], self.newHaplotypes[ e_id ], self.newPopulations[ e_id ])
        return( ev )


cdef class Mutations:
    cdef:
        vector[Py_ssize_t] nodeId, AS, DS, site
    def __init__(self):#AS = ancestral state, DS = derived state
        pass

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void AddMutation(self, Py_ssize_t nodeId, Py_ssize_t haplotype, Py_ssize_t newHaplotype):
        cdef:
            Py_ssize_t ASDSdigit4, site, digit4
        ASDSdigit4 = newHaplotype - haplotype
        site = 0
        while ASDSdigit4 >= 4:
            ASDSdigit4 = ASDSdigit4 / 4
            site += 1
        digit4 = int(4**site)
        self.nodeId.push_back(nodeId)
        self.DS.push_back(int(floor(newHaplotype / digit4)) % 4)
        self.AS.push_back(int(floor(haplotype / digit4)) % 4)
        self.site.push_back(int(site))
        # print("MutType, AS, DS: ", site, self.AS[self.AS.size()-1], self.DS[self.DS.size()-1])


class Population:
    def __init__(self, size=1000000, contactDensity=1.0):
        self.size = size
        self.contactDensity = contactDensity

class Lockdown:
    def __init__(self, conDenAfterLD=0.1, startLD=2, endLD=1):
        self.conDenAfterLD = conDenAfterLD
        self.startLD = startLD
        self.endLD = endLD


cdef class PopulationModel:
    cdef:
        Py_ssize_t globalInfectious
        int[::1] sizes, totalSusceptible, totalInfectious
        int[:,::1] susceptible
        double[::1] contactDensity, contactDensityBeforeLockdown, contactDensityAfterLockdown, startLD, endLD

    def __init__(self, populations, susceptible_num, lockdownModel=None):
        sizePop = len(populations)

        self.sizes = np.zeros(sizePop, dtype=np.int32)
        for i in range(sizePop):
            self.sizes[i] = populations[i].size

        self.totalSusceptible = np.zeros(sizePop, dtype=np.int32)
        self.totalInfectious = np.zeros(sizePop, dtype=np.int32)
        self.globalInfectious = 0

        self.susceptible = np.zeros((sizePop, susceptible_num), dtype=np.int32)
        for i in range(sizePop):
            self.susceptible[i, 0] = populations[i].size
            self.totalSusceptible[i] = populations[i].size

        self.contactDensity = np.zeros(sizePop, dtype=float)
        for i in range(sizePop):
            self.contactDensity[i] = populations[i].contactDensity

        if lockdownModel != None:
            self.contactDensityBeforeLockdown = np.zeros(sizePop, dtype=float)
            self.contactDensityAfterLockdown = np.zeros(sizePop, dtype=float)
            self.startLD = np.zeros(sizePop, dtype=float)
            self.endLD = np.zeros(sizePop, dtype=float)   
            for i in range(sizePop):
                self.contactDensityBeforeLockdown[i] = populations[i].contactDensity
                self.contactDensityAfterLockdown[i] = lockdownModel[i].conDenAfterLD
                self.startLD[i] = lockdownModel[i].startLD*self.sizes[i]/100
                self.endLD[i] = lockdownModel[i].endLD*self.sizes[i]/100

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef inline void NewInfection(self, Py_ssize_t popId, Py_ssize_t suscId):
        self.susceptible[popId, suscId] -= 1
        self.totalSusceptible[popId] -= 1
        self.totalInfectious[popId] += 1
        self.globalInfectious += 1

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef inline void NewRecovery(self, Py_ssize_t popId, Py_ssize_t suscId):
        self.susceptible[popId, suscId] += 1
        self.totalSusceptible[popId] += 1
        self.totalInfectious[popId] -= 1
        self.globalInfectious -= 1


cdef class BirthDeathModel:
    cdef:
        RndmWrapper rndm

        double currentTime, rn, totalRate, maxEffectiveBirth, totalMigrationRate
        Py_ssize_t bCounter, dCounter, sCounter, migCounter, mutCounter, popNum, dim, hapNum, susceptible_num, migPlus, migNonPlus
        Events events
        PopulationModel pm
        Mutations mut

        int[::1] tree, suscType
        int[:,::1] liveBranches

        double[::1] bRate, dRate, sRate, tmRate, migPopRate, popRate, elementsArr3, times, pm_maxEffectiveMigration, maxSusceptibility, elementsArr2
        double[:,::1] pm_migrationRates, pm_effectiveMigration, birthHapPopRate, tEventHapPopRate, hapPopRate, mRate, susceptibility
        double[:,:,::1] eventHapPopRate, susceptHapPopRate

    def __init__(self, iterations, bRate, dRate, sRate, mRate, populationModel=None, susceptible=None, lockdownModel=None, rndseed=1256, **kwargs):
        self.currentTime = 0.0
        self.sCounter = 0 #sample counter
        self.bCounter = 0
        self.dCounter = 0
        self.migCounter = 0
        self.mutCounter = 0
        self.events = Events(iterations+1)
        self.mut = Mutations()
        self.migPlus = 0
        self.migNonPlus = 0

        if susceptible == None:
            self.susceptible_num = 2
        else:
            self.susceptible_num = len( susceptible[0][0] )

        #Set population model
        if populationModel == None:
            self.pm = PopulationModel( [ Population() ], self.susceptible_num)
            self.pm_migrationRates = np.asarray((0, 0), dtype=float)
        else:
            self.pm = PopulationModel( populationModel[0] , self.susceptible_num, lockdownModel)
            self.pm_migrationRates = np.asarray(populationModel[1])
        self.popNum = self.pm.sizes.shape[0]
        self.pm_effectiveMigration = np.zeros((self.popNum, self.popNum), dtype=float)
        self.pm_maxEffectiveMigration = np.zeros(self.popNum, dtype=float)
        self.SetEffectiveMigration()

        #Initialise haplotypes
        if len(mRate) > 0:
            self.dim = len(mRate[0])
        else:
            self.dim = 0
        self.hapNum = int(4**self.dim)

        self.InitLiveBranches()

        self.elementsArr2 = np.zeros(2, dtype=float)
        self.elementsArr3 = np.ones(3)

        if susceptible == None:
            self.susceptibility = np.asarray( [ [1.0 for _ in range(self.hapNum)], [0.0 for _ in range(self.hapNum)] ] )
            self.suscType = np.ones(int(self.hapNum), dtype=np.int32)
        else:
            self.susceptibility = np.asarray( susceptible[0], dtype=float)
            self.suscType = np.asarray( susceptible[1], dtype=np.int32 )

        self.susceptHapPopRate = np.zeros((self.popNum, self.hapNum, self.susceptible_num), dtype=float)
        
        #Set rates
        self.SetRates(bRate, dRate, sRate, mRate)
        self.maxSusceptibility = np.zeros(self.hapNum, dtype=float)
        self.SetMaxBirth()
        self.migPopRate = np.zeros(len(self.pm_migrationRates), dtype=float)
        self.MigrationRates()

        #Set random generator
        self.rndm = RndmWrapper(seed=(rndseed, 0))

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void InitLiveBranches(self):
        self.liveBranches = np.zeros((self.popNum, self.hapNum), dtype=np.int32)
        # self.Birth(0, 0)
        self.events.AddEvent(self.currentTime, 0, 0, 0, 0, 0)
        self.liveBranches[0, 0] += 2
        self.pm.NewInfection(0, 0)
        self.pm.NewInfection(0, 0)
        #self.pm.susceptible[0, 0] -= 2

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void SetMaxBirth(self):
        for k in range(self.hapNum):
            self.maxSusceptibility[k] = 0.0
            for sType in range(self.susceptible_num):
                if self.susceptibility[sType, k] > self.maxSusceptibility[k]:
                    self.maxSusceptibility[k] = self.susceptibility[sType, k]
        self.maxEffectiveBirth = 0.0
        for k in range(self.hapNum):
            if self.maxEffectiveBirth < self.bRate[k]*self.maxSusceptibility[k]:
                self.maxEffectiveBirth = self.bRate[k]*self.maxSusceptibility[k]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void SetEffectiveMigration(self):
        for i in range(self.popNum):
            self.pm_maxEffectiveMigration[i] = 0.0
        for i in range(self.popNum):
            for j in range(self.popNum):
                self.pm_effectiveMigration[i,j] = self.pm_migrationRates[i,j]*self.pm.contactDensity[j]/self.pm.sizes[j]+self.pm_migrationRates[j,i]*self.pm.contactDensity[i]/self.pm.sizes[i]
                if self.pm_effectiveMigration[i,j] > self.pm_maxEffectiveMigration[j]:
                    self.pm_maxEffectiveMigration[j] = self.pm_effectiveMigration[i,j]
    #    for i in range(self.popNum):
    #        self.pm_maxEffectiveMigration[i] *= self.maxEffectiveBirth[i]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void SetRates(self, bRate, dRate, sRate, mRate):
        self.bRate, self.dRate, self.sRate = np.asarray(bRate), np.asarray(dRate), np.asarray(sRate)

        self.mRate = np.zeros((len(mRate), len(mRate[0])), dtype=float)
        for i in range(len(mRate)):
            for j in range(len(mRate[0])):
                self.mRate[i, j] = mRate[i][j]

        self.tmRate = np.zeros(len(mRate), dtype=float)
        for i in range(self.mRate.shape[0]):
            for j in range(self.mRate.shape[1]):
                self.tmRate[i] += self.mRate[i, j]

        #for i in range(len(self.pm_migrationRates)):
        #    for j in range(len(self.pm_migrationRates[0])):
        #        self.migPopRate[i] += self.pm_migrationRates[i, j]

        self.birthHapPopRate = np.zeros((self.popNum, self.hapNum), dtype=float)
        self.eventHapPopRate = np.zeros((self.popNum, self.hapNum, 4), dtype=float)
        self.tEventHapPopRate = np.zeros((self.popNum, self.hapNum), dtype=float)
        for pn in range(self.popNum):
            for hn in range(self.hapNum):
                self.birthHapPopRate[pn, hn] = self.BirthRate(pn, hn)

                #self.eventHapPopRate[pn][hn] = [self.birthHapPopRate[pn][hn], self.dRate[hn], self.sRate[hn], self.migPopRate[pn], self.tmRate[hn] ]
                self.eventHapPopRate[pn, hn, 0] = self.birthHapPopRate[pn, hn]
                self.eventHapPopRate[pn, hn, 1] = self.dRate[hn]
                self.eventHapPopRate[pn, hn, 2] = self.sRate[hn]
                #self.eventHapPopRate[pn, hn, 3] = self.migPopRate[pn]
                self.eventHapPopRate[pn, hn, 3] = self.tmRate[hn]

                #self.tEventHapPopRate[pn][hn] = sum(self.eventHapPopRate[pn][hn])
                for i in range(4):
                    self.tEventHapPopRate[pn, hn] += self.eventHapPopRate[pn, hn, i]

        #self.hapPopRate = [ [0.0 for hn in range(self.hapNum)] for pn in range(self.popNum) ]
        self.hapPopRate = np.zeros((self.popNum, self.hapNum), dtype=float)

        for pn in range(self.popNum):
            for hn in range(self.hapNum):
                self.HapPopRate(pn, hn)

        #self.popRate = [ sum(self.hapPopRate[pn]) for pn in range(self.popNum) ]
        self.popRate = np.zeros(self.popNum, dtype=float)
        for i in range(self.popNum):
            for j in range(self.hapNum):
                self.popRate[i] += self.hapPopRate[i, j]

        #self.totalRate = sum( self.popRate )
        self.totalRate = 0
        for i in range(self.popNum):
            self.totalRate += self.popRate[i]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef inline void HapPopRate(self, Py_ssize_t popId, Py_ssize_t haplotype):
        self.hapPopRate[popId, haplotype] = self.tEventHapPopRate[popId, haplotype]*self.liveBranches[popId, haplotype]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef inline double BirthRate(self, Py_ssize_t popId, Py_ssize_t haplotype):
        cdef double ws = 0.0
        for i in range(self.susceptible_num):
            self.susceptHapPopRate[popId, haplotype, i] = self.pm.susceptible[popId, i]*self.susceptibility[haplotype, i]
            ws += self.susceptHapPopRate[popId, haplotype, i]#TOVADIM

        return self.bRate[haplotype]*ws/self.pm.sizes[popId]*self.pm.contactDensity[popId]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef inline double MigrationRates(self):
        self.totalMigrationRate = 0.0
        for p in range(self.popNum):
            self.migPopRate[p] = self.pm_maxEffectiveMigration[p]*self.maxEffectiveBirth*self.pm.totalSusceptible[p]*(self.pm.globalInfectious-self.pm.totalInfectious[p])
            self.totalMigrationRate += self.migPopRate[p]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef Py_ssize_t GenerateEvent(self, useNumpy = False):
        cdef:
            Py_ssize_t popId, haplotype, eventType, et

        #self.rn = np.random.rand()
        self.rn = self.rndm.uniform()

        self.elementsArr2[0] = self.totalRate
        self.elementsArr2[1] = self.totalMigrationRate
        et, self.rn = fastChoose1( self.elementsArr2, self.totalRate+self.totalMigrationRate, self.rn)

        if et == 0:
            popId, self.rn = fastChoose1( self.popRate, self.totalRate, self.rn)
            haplotype, self.rn = fastChoose1( self.hapPopRate[popId], self.popRate[popId], self.rn)
            eventType, self.rn = fastChoose1( self.eventHapPopRate[popId, haplotype], self.tEventHapPopRate[popId, haplotype], self.rn)

            if eventType == BIRTH:
                self.Birth(popId, haplotype)
            elif eventType == DEATH:
                self.Death(popId, haplotype)
            elif eventType == SAMPLING:
                self.Sampling(popId, haplotype)
            #elif eventType == MIGRATION:
            #    self.Migration(popId, haplotype)
            else:
                self.Mutation(popId, haplotype)
        else:
            popId = self.GenerateMigration()
        return popId

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef Py_ssize_t GenerateMigration(self):
        cdef:
            Py_ssize_t targetPopId, sourcePopId, haplotype, suscType
            double p_accept
        targetPopId, self.rn = fastChoose1( self.migPopRate, self.totalMigrationRate, self.rn)
        sourcePopId, self.rn = fastChoose2_skip( self.pm.totalInfectious, self.pm.globalInfectious-self.pm.totalInfectious[targetPopId], self.rn, skip = targetPopId)
        haplotype, self.rn = fastChoose2( self.liveBranches[sourcePopId], self.pm.totalInfectious[sourcePopId], self.rn)
        suscType, self.rn = fastChoose2( self.pm.susceptible[targetPopId], self.pm.totalSusceptible[targetPopId], self.rn)
        p_accept = self.pm_effectiveMigration[sourcePopId, targetPopId]*self.bRate[haplotype]*self.susceptibility[suscType, haplotype]/self.pm_maxEffectiveMigration[targetPopId]/self.maxEffectiveBirth
        if p_accept < self.rn:
            self.liveBranches[targetPopId, haplotype] += 1
            self.pm.NewInfection(targetPopId, suscType)
            self.UpdateRates(targetPopId)
            self.MigrationRates()
            self.events.AddEvent(self.currentTime, MIGRATION, sourcePopId, haplotype, 0, targetPopId)
            self.migPlus += 1
            self.migCounter += 1
        else:
            self.migNonPlus += 1
        return targetPopId

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void Mutation(self, Py_ssize_t popId, Py_ssize_t haplotype):
        cdef:
            Py_ssize_t mutationType, digit4, AS, DS, newHaplotype

        mutationType, self.rn = fastChoose1( self.mRate[haplotype], self.tmRate[haplotype], self.rn)
        digit4 = 4**mutationType
        AS = int(floor(haplotype/digit4) % 4)
        DS, self.rn = fastChoose1(self.elementsArr3, 3.0, self.rn)#TODO non-uniform rates???
        if DS >= AS:
            DS += 1
        #self.mutations.append(Mutation(self.liveBranches[popId][haplotype][affectedBranch], self.currentTime, AS, DS))
        newHaplotype = haplotype + (DS-AS)*digit4

        # print("MutType, AS, DS: ", mutationType, AS, DS)

        self.liveBranches[popId, newHaplotype] += 1
        self.liveBranches[popId, haplotype] -= 1

        #event = Event(self.currentTime, 4, popId, haplotype, newHaplotype = newHaplotype)
        #self.events.append(event)
        self.events.AddEvent(self.currentTime, MUTATION, popId, haplotype, newHaplotype, 0)

        self.HapPopRate(popId, haplotype)
        self.HapPopRate(popId, newHaplotype)

        #self.popRate[popId] = sum(self.hapPopRate[popId])
        self.popRate[popId] = 0
        for i in range(self.hapNum):
            self.popRate[popId] += self.hapPopRate[popId, i]

        #self.totalRate = sum( self.popRate )
        self.totalRate = 0
        for i in range(self.popNum):
            self.totalRate += self.popRate[i]
        self.mutCounter += 1
        self.MigrationRates()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef inline void SampleTime(self):
        cdef double tau = - log(self.rndm.uniform()) / self.totalRate
        self.currentTime += tau

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void Birth(self, Py_ssize_t popId, Py_ssize_t haplotype):
        self.liveBranches[popId, haplotype] += 1

        cdef double ws = 0.0
        for i in range(self.susceptible_num):
            ws += self.susceptHapPopRate[popId, haplotype, i]#TOVADIM
        st, self.rn = fastChoose1(self.susceptHapPopRate[popId, haplotype], ws, self.rn)

        self.pm.NewInfection(popId, st)
        #self.pm.susceptible[popId, st] -= 1

        #event = Event(self.currentTime, 0, popId, haplotype)
        #self.events.append(event)
        self.events.AddEvent(self.currentTime, BIRTH, popId, haplotype, 0, 0)
        self.UpdateRates(popId)
        self.bCounter += 1
        self.MigrationRates()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void UpdateRates(self, Py_ssize_t popId):
        cdef double tmp

        for h in range(self.hapNum):
            self.birthHapPopRate[popId, h] = self.BirthRate(popId, h)
            self.eventHapPopRate[popId, h, 0] = self.birthHapPopRate[popId, h]
            # tmp = (self.eventHapPopRate[popId, h, 0] +
            #        self.eventHapPopRate[popId, h, 1] +
            #        self.eventHapPopRate[popId, h, 2] +
            #        self.eventHapPopRate[popId, h, 3] +
            #        self.eventHapPopRate[popId, h, 4] )
            tmp = (self.eventHapPopRate[popId, h, 0] +
                   self.eventHapPopRate[popId, h, 1] +
                   self.eventHapPopRate[popId, h, 2] +
                   self.eventHapPopRate[popId, h, 3] )
            self.tEventHapPopRate[popId, h] = tmp
            self.HapPopRate(popId, h)

        self.popRate[popId] = 0
        for i in range(self.hapNum):
            self.popRate[popId] += self.hapPopRate[popId, i]

        self.totalRate = 0
        for i in range(self.popNum):
            self.totalRate += self.popRate[i]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void Death(self, Py_ssize_t popId, Py_ssize_t haplotype, bint add_event = True):
        self.liveBranches[popId, haplotype] -= 1
        self.pm.NewRecovery(popId, self.suscType[haplotype])
        #self.pm.susceptible[popId, self.suscType[haplotype] ] += 1

        if add_event:
            #event = Event(self.currentTime, 1, popId, haplotype)
            #self.events.append(event)
            self.dCounter += 1
            self.events.AddEvent(self.currentTime, DEATH, popId, haplotype, 0, 0)

        self.UpdateRates(popId)
        self.MigrationRates()


    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void Sampling(self, Py_ssize_t popId, Py_ssize_t haplotype):
        #event = Event(self.currentTime, 2, popId, haplotype)
        #self.events.append(event)
        self.events.AddEvent(self.currentTime, SAMPLING, popId, haplotype, 0, 0)

        self.Death(popId, haplotype, False)
        self.sCounter += 1

#    def UpdateRate(self):
#        self.totalRate = self.B_rate[0] + self.D_rate[0] + self.S_rate[0] #TODO

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void SimulatePopulation(self, Py_ssize_t iterations):
        cdef Py_ssize_t popId
        max_time = 0
        sCounter = 0
        for j in range(0, iterations):
            self.SampleTime()
            popId = self.GenerateEvent()
            if self.pm.contactDensityBeforeLockdown.shape[0] > 0 and self.pm.globalInfectious > 0:
                self.CheckLockdown(popId)
            if self.totalRate == 0.0:
                break
        print("Total number of iterations: ", self.events.ptr)
        if self.sCounter < 2: #TODO if number of sampled leaves is 0 (probably 1 as well), then GetGenealogy seems to go to an infinite cycle
            print("Less than two cases were sampled...")
            print("_________________________________")
            sys.exit(0)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void CheckLockdown(self, Py_ssize_t popId):
        if self.pm.totalInfectious[popId] > self.pm.startLD[popId]:
            self.pm.contactDensity[popId] = self.pm.contactDensityAfterLockdown[popId] 
        if self.pm.totalInfectious[popId] < self.pm.endLD[popId]:
            self.pm.contactDensity[popId] = self.pm.contactDensityBeforeLockdown[popId] 
        self.SetEffectiveMigration()
        self.MigrationRates()
        self.UpdateRates(popId)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cpdef GetGenealogy(self):
        cdef:
            Py_ssize_t ptrTreeAndTime, n1, n2, id1, id2, id3, lbs, lbs_e, ns, nt, idt, ids, lbss
            double p
            vector[vector[vector[Py_ssize_t]]] liveBranchesS
            vector[vector[Py_ssize_t]] vecint2
            vector[Py_ssize_t] vecint1

            double e_time
            Py_ssize_t e_type_, e_population, e_haplotype, e_newHaplotype, e_newPopulation

        ptrTreeAndTime = 0
        self.tree = np.zeros(2 * self.sCounter - 1, dtype=np.int32)
        self.times = np.zeros(2 * self.sCounter - 1, dtype=float)

        # liveBranchesS = []
        # for i in range( self.popNum ):
        #     liveBranchesS.append( [[] for _ in range(self.hapNum)] )
        for i in range( self.popNum ):
            liveBranchesS.push_back(vecint2)
            for _ in range( self.hapNum ):
                liveBranchesS[i].push_back(vecint1)

        #for event in reversed(self.events):
        for e_id in range(self.events.ptr-1, -1, -1):
            # this event
            e_time = self.events.times[e_id]
            e_type_ = self.events.types[e_id]
            e_population = self.events.populations[e_id]
            e_haplotype = self.events.haplotypes[e_id]
            e_newHaplotype = self.events.newHaplotypes[e_id]
            e_newPopulation = self.events.newPopulations[e_id]
    
            if e_type_ == BIRTH:
                lbs = liveBranchesS[e_population][e_haplotype].size()
                lbs_e = self.liveBranches[e_population][e_haplotype]
                p = lbs*(lbs-1)/ lbs_e / (lbs_e - 1)
                # if lbs != lbs_e:
                #     print("-")
                # else:
                #     print("+")
                # if np.random.rand() < p:
                #     n1 = int(floor( lbs*np.random.rand() ))
                #     n2 = int(floor( (lbs-1)*np.random.rand() ))
                if self.rndm.uniform() < p:
                    n1 = int(floor( lbs*self.rndm.uniform() ))
                    n2 = int(floor( (lbs-1)*self.rndm.uniform() ))

                    if n2 >= n1:
                        n2 += 1
                    id1 = liveBranchesS[e_population][e_haplotype][n1]
                    id2 = liveBranchesS[e_population][e_haplotype][n2]

                    #id3 = len( self.tree )
                    id3 = ptrTreeAndTime

                    liveBranchesS[e_population][e_haplotype][n1] = id3
                    liveBranchesS[e_population][e_haplotype][n2] = liveBranchesS[e_population][e_haplotype][lbs-1]
                    liveBranchesS[e_population][e_haplotype].pop_back()
                    self.tree[id1] = id3
                    self.tree[id2] = id3

                    # print(lbs)
                    # print(lbs_e)
                    # print(p)
                    # print(n1)
                    # print(n2)
                    # print(id1)
                    # print(id2)
                    # print(id3)
                    # print(liveBranchesS[e_population][e_haplotype].size())
                    # print()
                    #self.tree.append(-1)
                    #self.times.append( event.time )
                    self.tree[ptrTreeAndTime] = -1
                    self.times[ptrTreeAndTime] = e_time
                    ptrTreeAndTime += 1
                    # print()
                self.liveBranches[e_population][e_haplotype] -= 1
            elif e_type_ == DEATH:
                self.liveBranches[e_population][e_haplotype] += 1
            elif e_type_ == SAMPLING:
                self.liveBranches[e_population][e_haplotype] += 1
                liveBranchesS[e_population][e_haplotype].push_back( ptrTreeAndTime )

                # self.tree.append(-1)
                # self.times.append( event.time )
                self.tree[ptrTreeAndTime] = -1
                self.times[ptrTreeAndTime] = e_time
                ptrTreeAndTime += 1
            elif e_type_ == MUTATION:
                lbs = liveBranchesS[e_population][e_newHaplotype].size()
                p = lbs/self.liveBranches[e_population][e_newHaplotype]

                # if np.random.rand() < p:
                #     n1 = int(floor( lbs*np.random.rand() ))
                if self.rndm.uniform() < p:
                    n1 = int(floor( lbs*self.rndm.uniform() ))

                    id1 = liveBranchesS[e_population][e_newHaplotype][n1]
                    liveBranchesS[e_population][e_newHaplotype][n1] = liveBranchesS[e_population][e_newHaplotype][lbs-1]
                    liveBranchesS[e_population][e_newHaplotype].pop_back()
                    liveBranchesS[e_population][e_haplotype].push_back(id1)
                    self.mut.AddMutation(id1, e_haplotype, e_newHaplotype)
                self.liveBranches[e_population][e_newHaplotype] -= 1
                self.liveBranches[e_population][e_haplotype] += 1
            elif e_type_ == MIGRATION:
                lbs = liveBranchesS[e_newPopulation][e_haplotype].size()
                p = lbs/self.liveBranches[e_newPopulation][e_haplotype]

                if self.rndm.uniform() < p:
                    nt = int(floor( lbs*self.rndm.uniform() ))
                    lbss = liveBranchesS[e_population][e_haplotype].size()
                    p1 = lbss/self.liveBranches[e_population][e_haplotype]
                    if self.rndm.uniform() < p1:
                        ns = int(floor( lbss*self.rndm.uniform() ))

                        idt = liveBranchesS[e_newPopulation][e_haplotype][nt]
                        ids = liveBranchesS[e_population][e_haplotype][ns]

                        id3 = ptrTreeAndTime

                        liveBranchesS[e_population][e_haplotype][ns] = id3
                        liveBranchesS[e_newPopulation][e_haplotype][nt] = liveBranchesS[e_newPopulation][e_haplotype][lbs-1]
                        liveBranchesS[e_newPopulation][e_haplotype].pop_back()
                        self.tree[idt] = id3
                        self.tree[ids] = id3
                        self.tree[ptrTreeAndTime] = -1
                        self.times[ptrTreeAndTime] = e_time
                        ptrTreeAndTime += 1
                    else: 
                        liveBranchesS[e_population][e_haplotype].push_back(liveBranchesS[e_newPopulation][e_haplotype][nt])
                        liveBranchesS[e_newPopulation][e_haplotype][nt] = liveBranchesS[e_newPopulation][e_haplotype][lbs-1]
                        liveBranchesS[e_newPopulation][e_haplotype].pop_back()
                self.liveBranches[e_newPopulation][e_haplotype] -= 1
            else:
                print("Unknown event type: ", e_type_)
                print("_________________________________")
                sys.exit(0)
        self.CheckTree()

    cdef void CheckTree(self):
        cdef Py_ssize_t counter
        counter = 0
        for i in range(self.sCounter * 2 - 1):
            if self.tree[i] == 0:
                print("Error 1")
                print("_________________________________")
                sys.exit(0)
            if self.tree[i] == 1:
                counter += 1
            if counter >= 2:
                print("Error 2")
                print("_________________________________")
                sys.exit(0)
            if self.tree[i] == i:
                print("Error 3")
                print("_________________________________")
                sys.exit(0)



    def LogDynamics(self, step_num = 1000):
        count = 0
        time_points = [i*self.currentTime/step_num for i in range(step_num+1)]
        dynamics = [None for i in range(step_num+1)]
        ptr = step_num
        for e_id in range(self.events.ptr-1, -1, -1):
            e_time = self.events.times[e_id]
            e_type_ = self.events.types[e_id]
            e_population = self.events.populations[e_id]
            e_haplotype = self.events.haplotypes[e_id]
            e_newHaplotype = self.events.newHaplotypes[e_id]
            e_newPopulation = self.events.newPopulations[e_id]

            if e_type_ == BIRTH:
                self.liveBranches[e_population][e_haplotype] -= 1
            elif e_type_ == DEATH:
                self.liveBranches[e_population][e_haplotype] += 1
            elif e_type_ == SAMPLING:
                self.liveBranches[e_population][e_haplotype] += 1
            elif e_type_ == MIGRATION:
                self.liveBranches[e_newPopulation][e_haplotype] -= 1
            elif e_type_ == MUTATION:
                self.liveBranches[e_population][e_newHaplotype] -= 1
                self.liveBranches[e_population][e_haplotype] += 1

            while ptr >= 0 and time_points[ptr] >= e_time:
                dynamics[ptr] = [ [el for el in br] for br in self.liveBranches]
                ptr -= 1
        return([time_points, dynamics])

    def Debug(self):
        print("Parameters")
        print("Migration plus: ", self.migPlus)
        print("Migration non plus: ", self.migNonPlus)
        print("Current time(mutable): ", self.currentTime)
        print("Random number(mutable): ", self.rn)
        print("Total rate(mutable): ", self.totalRate)
        print("Max effective birth(const): ", self.maxEffectiveBirth)
        print("Total migration rate(mutable): ", self.totalMigrationRate)
        print("Birth counter(mutable): ", self.bCounter)
        print("Death counter(mutable): ", self.dCounter)
        print("Sampling counter(mutable): ", self.sCounter)
        print("Migration counter(mutable): ", self.migCounter)
        print("Mutation counter(mutable): ", self.mutCounter)
        print("Populations number(const): ", self.popNum)
        print("Mutations number(const): ", self.dim)
        print("Haplotypes number(const): ", self.hapNum)
        print("Susceptible number(const): ", self.susceptible_num)
        print("Population model - globalInfectious(mutable): ", self.pm.globalInfectious)
        print("Susceptible type(): ", sep=" ", end="")
        for i in range(self.suscType.shape[0]):
            print(self.suscType[i], end=" ")
        print()
        print("Birth rate(const): ", sep="", end="")
        for i in range(self.hapNum):
            print(self.bRate[i], end=" ")
        print()
        print("Death rate(const): ", sep="", end="")
        for i in range(self.hapNum):
            print(self.dRate[i], end=" ")
        print()
        print("Sampling rate(const): ", sep="", end="")
        for i in range(self.hapNum):
            print(self.sRate[i], end=" ")
        print()
        print("Total mutation rate(const): ", sep="", end="")
        for i in range(self.hapNum):
            print(self.tmRate[i], end=" ")
        print()
        print("Migration population rate(mutable): ", sep="", end="")
        for i in range(self.popNum):
            print(self.migPopRate[i], end=" ")
        print()
        print("Population rate(mutable): ", sep="", end="")
        for i in range(self.popNum):
            print(self.popRate[i], end=" ")
        print()
        print("Population model - sizes(const): ", end="")
        for i in range(self.pm.sizes.shape[0]):
            print(self.pm.sizes[i], end=" ")
        print()
        print("Population model - totalSusceptible(mutable): ", end="")
        for i in range(self.pm.totalSusceptible.shape[0]):
            print(self.pm.totalSusceptible[i], end=" ")
        print()
        print("Population model - totalInfectious(mutable): ", end="")
        for i in range(self.pm.totalInfectious.shape[0]):
            print(self.pm.totalInfectious[i], end=" ")
        print()
        print("Population model - contac density(const): ", end=" ")
        for i in range(self.pm.sizes.shape[0]):
            print(self.pm.contactDensity[i], end=" ")
        print()
        print("Population model - max effective migration(const): ", end=" ")
        for i in range(self.pm_maxEffectiveMigration.shape[0]):
            print(self.pm_maxEffectiveMigration[i], end=" ")
        print()
        print("Population model - max susceptibility(const): ", end=" ")
        for i in range(self.maxSusceptibility.shape[0]):
            print(self.maxSusceptibility[i], end=" ")
        print()

        print("Population model - contactDensityAfterLockdown(const): ", end=" ")
        for i in range(self.pm.contactDensityAfterLockdown.shape[0]):
            print(self.pm.contactDensityAfterLockdown[i], end=" ")
        print()
        print("Population model - startLD(const): ", end=" ")
        for i in range(self.pm.startLD.shape[0]):
            print(self.pm.startLD[i], end=" ")
        print()
        print("Population model - endLD(const): ", end=" ")
        for i in range(self.pm.endLD.shape[0]):
            print(self.pm.endLD[i], end=" ")
        print()


        print("Population model - susceptible(mutable)----")
        for i in range(self.pm.sizes.shape[0]):
            for j in range(self.susceptible_num):
                print(self.pm.susceptible[i, j], end=" ")
            print()
        print()
        print("Population model - migration rates(const)----")
        for i in range(self.pm_migrationRates.shape[0]):
            for j in range(self.pm_migrationRates.shape[1]):
                print(self.pm_migrationRates[i, j], end=" ")
            print()
        print()
        print("Population model - effective migration(const)----")
        for i in range(self.pm_effectiveMigration.shape[0]):
            for j in range(self.pm_effectiveMigration.shape[1]):
                print(self.pm_effectiveMigration[i, j], end=" ")
            print()
        print()
        print("Total event haplotype population rate(mutable)----")
        for i in range(self.popNum):
            for j in range(self.hapNum):
                print(self.tEventHapPopRate[i, j], end=" ")
            print()
        print()
        print("Haplotypes populations rates(mutable)----")
        for i in range(self.popNum):
            for j in range(self.hapNum):
                print(self.hapPopRate[i, j], end=" ")
            print()
        print()
        print("Mutation rate(const)----")
        for i in range(self.hapNum):
            for j in range(self.dim):
                print(self.mRate[i, j], end=" ")
            print()
        print()
        print("Susceptibility(const)----")
        for i in range(self.susceptibility.shape[0]):
            for j in range(self.susceptibility.shape[1]):
                print(self.susceptibility[i, j], end=" ")
            print()
        print()
        print("Birth haplotypes populations rate(mutable)----")
        for i in range(self.popNum):
            for j in range(self.hapNum):
                print(self.birthHapPopRate[i, j], end=" ")
            print()
        print("Event haplotypes populations rate(mutable)----")
        for i in range(self.popNum):
            for j in range(self.hapNum):
                for k in range(4):
                    print(self.eventHapPopRate[i, j, k], end=" ")
                print()
            print()
        print()
        print("Susceptible haplotypes populations rate(mutable)----")
        for i in range(self.popNum):
            for j in range(self.hapNum):
                for k in range(self.susceptible_num):
                    print(self.susceptHapPopRate[i, j, k], end=" ")
                print()
            print()
        print()

    def Report(self):
        print("Number of lineages of each hyplotype: ", end = "")
        for el in self.liveBranches:
            print(len(el), " ", end="")
        print("")
        print("popNum: ", self.popNum)
        print("dim: ", self.dim)
        print("hapNum: ", self.hapNum)
        print("totalRate: ", self.totalRate)
        print("rn: ", self.rn)
        #print("susceptible: ", self.susceptible)
        print("Current time: ", self.currentTime)
        print("Tree size: ", len(self.tree))
        print("Number of sampled elements: ", self.sCounter)
        print("")