# cython: language_level=3
# cython: initializedcheck = False
# distutils: language = c++

cimport cython

from libc.math cimport log, floor, abs
from libcpp.vector cimport vector
from mc_lib.rndm cimport RndmWrapper

from prettytable import PrettyTable
import numpy as np
import sys
import os

include "fast_choose.pxi"
include "models.pxi"


# use named constants for event types
DEF BIRTH = 0
DEF DEATH = 1
DEF SAMPLING = 2
DEF MUTATION = 3
DEF SUSCCHANGE = 4
DEF MIGRATION = 5


cdef class Event:
    cdef:
        Py_ssize_t type_, haplotype, population, newHaplotype, newPopulation
        double time

    def __init__(self, double time, Py_ssize_t type_, Py_ssize_t haplotype, Py_ssize_t population, Py_ssize_t newHaplotype, Py_ssize_t newPopulation):
        self.time = time
        self.type_ = type_
        self.haplotype = haplotype
        self.population = population
        self.newHaplotype = newHaplotype
        self.newPopulation = newPopulation


cdef class Events:
    cdef:
        Py_ssize_t size, ptr

        Py_ssize_t[::1] types, haplotypes, populations, newHaplotypes, newPopulations
        double[::1] times

    def __init__(self):
        self.size = 0
        self.ptr = 0#pointer to the first empty cell

        self.times = np.zeros(1, dtype=float)
        self.types = np.zeros(1, dtype=int)
        self.haplotypes = np.zeros(1, dtype=int)
        self.populations = np.zeros(1, dtype=int)
        self.newHaplotypes = np.zeros(1, dtype=int)
        self.newPopulations = np.zeros(1, dtype=int)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void AddEvent(self, double time_, Py_ssize_t type_, Py_ssize_t haplotype, Py_ssize_t population, Py_ssize_t newHaplotype, Py_ssize_t newPopulation):
        self.times[ self.ptr ] = time_
        self.types[ self.ptr ] = type_
        self.haplotypes[ self.ptr ] = haplotype
        self.populations[ self.ptr ] = population
        self.newHaplotypes[ self.ptr ] = newHaplotype
        self.newPopulations[ self.ptr ] = newPopulation
        self.ptr += 1

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef Event GetEvent(self, Py_ssize_t e_id):
        ev = Event( self.times[ e_id ], self.types[ e_id ], self.haplotypes[ e_id ], self.populations[ e_id ], self.newHaplotypes[ e_id ], self.newPopulations[ e_id ])
        return( ev )

    cdef void CreateEvents(self, Py_ssize_t iterations):
        self.size = iterations + self.ptr
        self.times = np.resize(self.times, self.size)
        self.types = np.resize(self.types, self.size)
        self.haplotypes = np.resize(self.haplotypes, self.size)
        self.populations = np.resize(self.populations, self.size)
        self.newHaplotypes = np.resize(self.newHaplotypes, self.size)
        self.newPopulations = np.resize(self.newPopulations, self.size)


cdef class multiEvent:
    cdef:
        Py_ssize_t num, type_, haplotype, population, newHaplotype, newPopulation
        double time

    def __init__(self, Py_ssize_t num, double time, Py_ssize_t type_, Py_ssize_t haplotype, Py_ssize_t population, Py_ssize_t newHaplotype, Py_ssize_t newPopulation):
        self.num = num
        self.time = time
        self.type_ = type_
        self.haplotype = haplotype
        self.population = population
        self.newHaplotype = newHaplotype
        self.newPopulation = newPopulation

    def PrintEvent(self):
        if self.type_ == BIRTH:
            tn = "B"
        elif  self.type_ == DEATH:
            tn = "D"
        elif  self.type_ == SAMPLING:
            tn = "S"
        elif  self.type_ == MUTATION:
            tn = "MUT"
        elif  self.type_ == SUSCCHANGE:
            tn = "SUS"
        elif  self.type_ == MIGRATION:
            tn = "MIG"
        print("num=", self.num,
                      "  time=", self.time,
                      "  type=", tn,
                      "  hap=", self.haplotype,
                      "  pop=", self.population,
                      "  dest1=", self.newHaplotype,
                      "  dest2=", self.newPopulation)

cdef class multiEvents:
    cdef:
        Py_ssize_t size, ptr

        Py_ssize_t[::1] num, types, haplotypes, populations, newHaplotypes, newPopulations
        double[::1] times

    def __init__(self):
        self.size = 0
        self.ptr = 0#pointer to the first empty cell

        self.num = np.zeros(1, dtype=int)
        self.times = np.zeros(1, dtype=float)
        self.types = np.zeros(1, dtype=int)
        self.haplotypes = np.zeros(1, dtype=int)
        self.populations = np.zeros(1, dtype=int)
        self.newHaplotypes = np.zeros(1, dtype=int)
        self.newPopulations = np.zeros(1, dtype=int)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void AddEvents(self, Py_ssize_t num, double time_, Py_ssize_t type_, Py_ssize_t haplotype, Py_ssize_t population, Py_ssize_t newHaplotype, Py_ssize_t newPopulation):
        self.num[ self.ptr ] = num
        self.times[ self.ptr ] = time_
        self.types[ self.ptr ] = type_
        self.haplotypes[ self.ptr ] = haplotype
        self.populations[ self.ptr ] = population
        self.newHaplotypes[ self.ptr ] = newHaplotype
        self.newPopulations[ self.ptr ] = newPopulation
        self.ptr += 1

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef multiEvent GetEvent(self, Py_ssize_t e_id):
        ev = multiEvent( self.num[ e_id ], self.times[ e_id ], self.types[ e_id ], self.haplotypes[ e_id ], self.populations[ e_id ], self.newHaplotypes[ e_id ], self.newPopulations[ e_id ])
        return( ev )

    cdef void CreateEvents(self, Py_ssize_t iterations):
        self.size = iterations + self.ptr
        self.num = np.resize(self.num, self.size)
        self.times = np.resize(self.times, self.size)
        self.types = np.resize(self.types, self.size)
        self.haplotypes = np.resize(self.haplotypes, self.size)
        self.populations = np.resize(self.populations, self.size)
        self.newHaplotypes = np.resize(self.newHaplotypes, self.size)
        self.newPopulations = np.resize(self.newPopulations, self.size)

#pi - population ID, pn - popoulation number, spi - source population ID, tpi - target population ID
#hi - haplotype ID, hn - haplotype number, nhi - new haplotype number
#si - susceptibility ID, sn - susceptibility number, ssi - source susceptibility ID, tsi - target susceptibility ID
cdef class BirthDeathModel:
    cdef:
        RndmWrapper rndm

        bint first_simulation, sampling_probability, strong_migration
        Py_ssize_t sites, hapNum, popNum, susNum, bCounter, dCounter, sCounter, mCounter, iCounter
        double currentTime, seed, maxEffectiveBirth, totalRate, totalMigrationRate, totalLen, rn, tau_l

        Events events
        multiEvents multievents

        PopulationModel pm
        Mutations mut

        long[::1] suscType, tree

        double[::1] bRate, dRate, sRate, tmRate, maxEffectiveBirthMigration, maxSusceptibility, suscepCumulTransition, immunePopRate, infectPopRate, popRate, migPopRate, times, tau
        double[:,::1] mRate, totalHapMutType, tEventHapPopRate, susceptibility, suscepTransition, immuneSourcePopRate, hapPopRate
        double[:,:,::1] hapMutType, eventHapPopRate, susceptHapPopRate

        double[:,:,:,::1] PropensitiesMigr, PropensitiesMutatations
        double[:,:,::1] PropensitiesSuscep, PropensitiesTransmission
        double[:,::1] PropensitiesRecovery, PropensitiesSampling

        long[:,:,:,::1] eventsMigr, eventsMutatations
        long[:,:,::1] eventsSuscep, eventsTransmission
        long[:,::1] eventsRecovery, eventsSampling
        double[:,:,::1] infectiousAuxTau, susceptibleAuxTau

    def __init__(self, sites_number, populations_number, susceptibility_types, seed, sampling_probability, strong_migration):
        self.rndm = RndmWrapper(seed=(seed, 0))

        self.first_simulation = False
        self.sampling_probability = sampling_probability
        self.strong_migration = strong_migration

        self.sites = sites_number
        self.hapNum = 4**self.sites
        self.susNum = susceptibility_types
        self.popNum = populations_number

        self.bCounter = 0
        self.dCounter = 0
        self.sCounter = 0
        self.mCounter = 0
        self.iCounter = 0

        self.tau_l=0.01

        self.currentTime = 0.0
        #Set random generator
        self.seed = seed
        self.maxEffectiveBirth = 0.0
        self.totalRate = 0.0
        self.totalMigrationRate = 0.0

        self.events = Events()
        self.multievents = multiEvents()

        self.mut = Mutations()
        self.pm = PopulationModel(self.popNum, self.susNum, self.hapNum, self.strong_migration)

        self.suscType = np.zeros(self.hapNum, dtype=np.int64)

        self.bRate = np.zeros(self.hapNum, dtype=float)
        self.dRate = np.zeros(self.hapNum, dtype=float)
        self.sRate = np.zeros(self.hapNum, dtype=float)
        self.tmRate = np.zeros(self.hapNum, dtype=float)
        self.maxEffectiveBirthMigration = np.zeros(self.popNum, dtype=float)
        self.maxSusceptibility = np.zeros(self.hapNum, dtype=float)
        self.suscepCumulTransition = np.zeros(self.susNum, dtype=float)
        self.infectPopRate = np.zeros(self.popNum, dtype=float)
        self.immunePopRate = np.zeros(self.popNum, dtype=float)
        self.popRate = np.zeros(self.popNum, dtype=float)
        self.migPopRate = np.zeros(self.popNum, dtype=float)

        self.mRate = np.zeros((self.hapNum, self.sites), dtype=float)
        self.totalHapMutType = np.zeros((self.hapNum, self.sites), dtype=float)
        self.tEventHapPopRate = np.zeros((self.popNum, self.hapNum), dtype=float)
        self.susceptibility = np.zeros((self.hapNum, self.susNum), dtype=float)
        self.suscepTransition = np.zeros( (self.susNum, self.susNum), dtype=float)
        self.immuneSourcePopRate = np.zeros((self.popNum, self.susNum), dtype=float)
        self.hapPopRate = np.zeros((self.popNum, self.hapNum), dtype=float)

        self.hapMutType = np.ones((self.hapNum, self.sites, 3), dtype=float)
        self.eventHapPopRate = np.zeros((self.popNum, self.hapNum, 4), dtype=float)
        self.susceptHapPopRate = np.zeros((self.popNum, self.hapNum, self.susNum), dtype=float)

        for hn in range(self.hapNum):
            self.bRate[hn] = 2.0
            self.dRate[hn] = 1.0
            self.sRate[hn] = 0.01
            for s in range(self.sites):
                self.mRate[hn, s] = 0.01
                self.totalHapMutType[hn, s] = 3
            self.susceptibility[hn, 0] = 1.0

        self.UpdateAllRates()

        #Init propensities
        self.PropensitiesMigr = np.zeros((self.popNum, self.popNum, self.susNum, self.hapNum), dtype=float)
        self.PropensitiesSuscep = np.zeros((self.popNum, self.susNum, self.susNum), dtype=float)
        self.PropensitiesRecovery = np.zeros((self.popNum, self.hapNum), dtype=float)
        self.PropensitiesSampling = np.zeros((self.popNum, self.hapNum), dtype=float)
        self.PropensitiesMutatations = np.zeros((self.popNum, self.hapNum, self.sites, 3), dtype=float)
        self.PropensitiesTransmission = np.zeros((self.popNum, self.hapNum, self.susNum), dtype=float)

        #Sampled number of events per step
        self.eventsMigr = np.zeros((self.popNum, self.popNum, self.susNum, self.hapNum), dtype=np.int64)
        self.eventsSuscep = np.zeros((self.popNum, self.susNum, self.susNum), dtype=np.int64)
        self.eventsRecovery = np.zeros((self.popNum, self.hapNum), dtype=np.int64)
        self.eventsSampling = np.zeros((self.popNum, self.hapNum), dtype=np.int64)
        self.eventsMutatations = np.zeros((self.popNum, self.hapNum, self.sites, 3), dtype=np.int64)
        self.eventsTransmission = np.zeros((self.popNum, self.hapNum, self.susNum), dtype=np.int64)

        self.infectiousAuxTau = np.zeros((self.popNum, self.hapNum, 2), dtype=float)
        self.susceptibleAuxTau = np.zeros((self.popNum, self.susNum, 2), dtype=float)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void UpdateAllRates(self):
        self.pm.UpdateAllRates()

        for sn1 in range(self.susNum):
            self.suscepCumulTransition[sn1] = 0
            for sn2 in range(self.susNum):
                self.suscepCumulTransition[sn1] += self.suscepTransition[sn1, sn2]

        self.totalRate = 0.0
        for pn in range(self.popNum):
            self.infectPopRate[pn] = 0
            self.immunePopRate[pn] = 0
            self.popRate[pn] = 0
        for pn in range(self.popNum):
            for hn in range(self.hapNum):
                self.tmRate[hn] = 0
                for s in range(self.sites):
                    self.tmRate[hn] += self.mRate[hn, s]

                self.eventHapPopRate[pn, hn, 0] = self.BirthRate(pn, hn)
                self.eventHapPopRate[pn, hn, 1] = self.dRate[hn]
                self.eventHapPopRate[pn, hn, 2] = self.sRate[hn] * self.pm.samplingMultiplier[pn]
                self.eventHapPopRate[pn, hn, 3] = self.tmRate[hn]
                self.tEventHapPopRate[pn, hn] = 0
                for i in range(4):
                    self.tEventHapPopRate[pn, hn] += self.eventHapPopRate[pn, hn, i]
                self.hapPopRate[pn, hn] = self.tEventHapPopRate[pn, hn] * self.pm.liveBranches[pn, hn]
                self.infectPopRate[pn] += self.hapPopRate[pn, hn]
            for sn in range(self.susNum):
                self.immuneSourcePopRate[pn, sn] = self.suscepCumulTransition[sn] * self.pm.susceptible[pn, sn]
                self.immunePopRate[pn] += self.immuneSourcePopRate[pn, sn]
            self.popRate[pn] = self.infectPopRate[pn] + self.immunePopRate[pn]
            self.totalRate += self.popRate[pn]


        self.maxEffectiveBirth = 0.0
        for hn in range(self.hapNum):
            self.maxSusceptibility[hn] = 0.0
            for sn in range(self.susNum):
                if self.susceptibility[hn, sn] > self.maxSusceptibility[hn]:
                    self.maxSusceptibility[hn] = self.susceptibility[hn, sn]
            if self.maxEffectiveBirth < self.bRate[hn]*self.maxSusceptibility[hn]:
                self.maxEffectiveBirth = self.bRate[hn]*self.maxSusceptibility[hn]

        self.totalMigrationRate = 0.0
        for pn in range(self.popNum):
            self.maxEffectiveBirthMigration[pn] = self.pm.maxEffectiveMigration[pn]*self.maxEffectiveBirth
            self.migPopRate[pn] = self.maxEffectiveBirthMigration[pn]*self.pm.totalSusceptible[pn]*(self.pm.globalInfectious-self.pm.totalInfectious[pn])
            self.totalMigrationRate += self.migPopRate[pn]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef inline double BirthRate(self, Py_ssize_t pi, Py_ssize_t hi):
        cdef double ws = 0.0
        for sn in range(self.susNum):
            self.susceptHapPopRate[pi, hi, sn] = self.pm.susceptible[pi, sn]*self.susceptibility[hi, sn]
            ws += self.susceptHapPopRate[pi, hi, sn]

        #return self.bRate[hi]*ws/self.pm.sizes[pi]*self.pm.contactDensity[pi]
        return self.bRate[hi]*ws*self.pm.migrationRates[pi, pi]*self.pm.migrationRates[pi, pi]/self.pm.effectiveSizes[pi]*self.pm.contactDensity[pi]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void SimulatePopulation(self, Py_ssize_t iterations, Py_ssize_t sample_size, float time):
        cdef Py_ssize_t pi
        self.events.CreateEvents(iterations)
        if self.first_simulation == False:
            self.pm.FirstInfection()
            self.first_simulation = True
        self.UpdateAllRates()
        #self.totalLen = 0.0
        if self.totalRate != 0.0 and self.pm.globalInfectious != 0:
            while (self.events.ptr<self.events.size and self.sCounter<=sample_size and (time==-1 or self.currentTime<time)):
                self.SampleTime()
                pi = self.GenerateEvent()
                if self.totalRate == 0.0 or self.pm.globalInfectious == 0:
                    break
                self.CheckLockdown(pi)

        if self.events.ptr>=self.events.size:
            print("Iterations")
        if self.sCounter>sample_size:
            print("Sample size")
        if self.currentTime>time and time != -1:
            print("Time")

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef inline void SampleTime(self):
        cdef double tau = - log(self.rndm.uniform()) / self.totalRate
        self.currentTime += tau
        #self.totalLen += tau*self.pm.globalInfectious

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef Py_ssize_t GenerateEvent(self):
        cdef:
            Py_ssize_t pi, hi, ei

        self.rn = self.rndm.uniform()
        if self.totalRate > self.rn * (self.totalRate + self.totalMigrationRate):
            self.rn = self.rn * (self.totalRate + self.totalMigrationRate) / self.totalRate
            pi, self.rn = fastChoose1(self.popRate, self.totalRate, self.rn)
            if self.immunePopRate[pi] > self.rn * self.popRate[pi]:
                self.rn = self.rn * self.popRate[pi] / self.immunePopRate[pi]
                self.ImmunityTransition(pi)
            else:
                self.rn = (self.rn * self.popRate[pi] - self.immunePopRate[pi]) / self.infectPopRate[pi]
                hi, self.rn = fastChoose1(self.hapPopRate[pi], self.infectPopRate[pi], self.rn)
                ei, self.rn = fastChoose1(self.eventHapPopRate[pi, hi], self.tEventHapPopRate[pi, hi], self.rn)
                if ei == BIRTH:
                    self.Birth(pi, hi)
                elif ei == DEATH:
                    self.Death(pi, hi)
                elif ei == SAMPLING:
                    self.Sampling(pi, hi)
                else:
                    self.Mutation(pi, hi)
        else:
            self.rn = (self.rn * (self.totalRate + self.totalMigrationRate) - self.totalRate) / self.totalMigrationRate
            pi = self.GenerateMigration()
        self.UpdateRates(pi)
        return pi

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void ImmunityTransition(self, Py_ssize_t pi):
        cdef:
            Py_ssize_t si, ti
        si, self.rn = fastChoose1( self.immuneSourcePopRate[pi], self.immunePopRate[pi], self.rn)
        ti, self.rn = fastChoose1( self.suscepTransition[si], self.suscepCumulTransition[si], self.rn)

        self.pm.susceptible[pi, si] -= 1
        self.pm.susceptible[pi, ti] += 1

        self.immuneSourcePopRate[pi, si] = self.pm.susceptible[pi, si]*self.suscepCumulTransition[si]
        self.immuneSourcePopRate[pi, ti] = self.pm.susceptible[pi, ti]*self.suscepCumulTransition[ti]
        self.immunePopRate[pi] = 0.0
        for sn in range(self.susNum):
            self.immunePopRate[pi] += self.immuneSourcePopRate[pi, sn]

        self.iCounter += 1
        self.events.AddEvent(self.currentTime, SUSCCHANGE, si, pi, ti, 0)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void Birth(self, Py_ssize_t pi, Py_ssize_t hi):
        cdef double ws = 0.0
        for sn in range(self.susNum):
            ws += self.susceptHapPopRate[pi, hi, sn]
        si, self.rn = fastChoose1(self.susceptHapPopRate[pi, hi], ws, self.rn)

        self.pm.NewInfection(pi, si, hi)

        self.immuneSourcePopRate[pi, si] = self.pm.susceptible[pi, si]*self.suscepCumulTransition[si]
        self.immunePopRate[pi] = 0.0
        for sn in range(self.susNum):
            self.immunePopRate[pi] += self.immuneSourcePopRate[pi, sn]

        self.bCounter += 1
        self.events.AddEvent(self.currentTime, BIRTH, hi, pi, si, 0)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void Death(self, Py_ssize_t pi, Py_ssize_t hi, bint add_event = True):
        self.pm.NewRecovery(pi, self.suscType[hi], hi)

        self.immuneSourcePopRate[pi, self.suscType[hi]] = self.pm.susceptible[pi, self.suscType[hi]]*self.suscepCumulTransition[self.suscType[hi]]
        self.immunePopRate[pi] = 0.0
        for sn in range(self.susNum):
            self.immunePopRate[pi] += self.immuneSourcePopRate[pi, sn]

        if add_event:
            self.dCounter += 1
            self.events.AddEvent(self.currentTime, DEATH, hi, pi, self.suscType[hi], 0)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void Sampling(self, Py_ssize_t pi, Py_ssize_t hi):
        self.Death(pi, hi, False)

        self.sCounter += 1
        self.events.AddEvent(self.currentTime, SAMPLING, hi, pi, self.suscType[hi], 0)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void Mutation(self, Py_ssize_t pi, Py_ssize_t hi):
        cdef:
            Py_ssize_t mi, digit4, AS, DS, nhi

        mi, self.rn = fastChoose1( self.mRate[hi], self.tmRate[hi], self.rn)
        digit4 = 4**mi
        AS = int(floor(hi/digit4) % 4)
        DS, self.rn = fastChoose1(self.hapMutType[hi, mi], self.totalHapMutType[hi, mi], self.rn)
        if DS >= AS:
            DS += 1
        nhi = hi + (DS-AS)*digit4

        self.pm.liveBranches[pi, nhi] += 1
        self.pm.liveBranches[pi, hi] -= 1

        self.hapPopRate[pi, hi] = self.tEventHapPopRate[pi, hi]*self.pm.liveBranches[pi, hi]
        self.hapPopRate[pi, nhi] = self.tEventHapPopRate[pi, nhi]*self.pm.liveBranches[pi, nhi]

        self.infectPopRate[pi] = 0
        for hn in range(self.hapNum):
            self.infectPopRate[pi] += self.hapPopRate[pi, hn]
        self.popRate[pi] = self.infectPopRate[pi] + self.immunePopRate[pi]
        self.totalRate = 0
        for pn in range(self.popNum):
            self.totalRate += self.popRate[pn]

        self.mCounter += 1
        self.events.AddEvent(self.currentTime, MUTATION, hi, pi, nhi, 0)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef Py_ssize_t GenerateMigration(self):
        cdef:
            Py_ssize_t tpi, spi, hi, si
        tpi, self.rn = fastChoose1( self.migPopRate, self.totalMigrationRate, self.rn)
        spi, self.rn = fastChoose2_skip( self.pm.totalInfectious, self.pm.globalInfectious-self.pm.totalInfectious[tpi], self.rn, skip = tpi)
        hi, self.rn = fastChoose2( self.pm.liveBranches[spi], self.pm.totalInfectious[spi], self.rn)
        si, self.rn = fastChoose2( self.pm.susceptible[tpi], self.pm.totalSusceptible[tpi], self.rn)
        if self.rn < self.pm.effectiveMigration[spi, tpi]*self.bRate[hi]*self.susceptibility[hi, si]/self.pm.maxEffectiveMigration[tpi]/self.maxEffectiveBirth:
            self.pm.NewInfection(tpi, si, hi)

            self.immuneSourcePopRate[tpi, si] = self.pm.susceptible[tpi, si]*self.suscepCumulTransition[si]
            self.immunePopRate[tpi] = 0.0
            for sn in range(self.susNum):
                self.immunePopRate[tpi] += self.immuneSourcePopRate[tpi, sn]

            self.pm.migPlus += 1
            self.pm.migCounter += 1
            self.events.AddEvent(self.currentTime, MIGRATION, hi, spi, si, tpi)
        else:
            self.pm.migNonPlus += 1
        return tpi

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void UpdateRates(self, Py_ssize_t pi):
        cdef double tmp

        self.infectPopRate[pi] = 0.0
        for hn in range(self.hapNum):
            self.eventHapPopRate[pi, hn, 0] = self.BirthRate(pi, hn)
            tmp = (self.eventHapPopRate[pi, hn, 0] +
                   self.eventHapPopRate[pi, hn, 1] +
                   self.eventHapPopRate[pi, hn, 2] +
                   self.eventHapPopRate[pi, hn, 3] )
            self.tEventHapPopRate[pi, hn] = tmp
            self.hapPopRate[pi, hn] = self.tEventHapPopRate[pi, hn] * self.pm.liveBranches[pi, hn]
            self.infectPopRate[pi] += self.hapPopRate[pi, hn]
        self.immunePopRate[pi] = 0
        for sn in range(self.susNum):
            self.immuneSourcePopRate[pi, sn] = self.suscepCumulTransition[sn] * self.pm.susceptible[pi, sn]
            self.immunePopRate[pi] += self.immuneSourcePopRate[pi, sn]
        self.popRate[pi] = self.infectPopRate[pi] + self.immunePopRate[pi]
        self.totalRate = 0.0
        for pn in range(self.popNum):
            self.totalRate += self.popRate[pn]

        self.totalMigrationRate = 0.0
        for pn in range(self.popNum):
            self.migPopRate[pn] = self.maxEffectiveBirthMigration[pn]*self.pm.totalSusceptible[pn]*(self.pm.globalInfectious-self.pm.totalInfectious[pn])
            self.totalMigrationRate += self.migPopRate[pn]

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void CheckLockdown(self, Py_ssize_t pi):
        if self.pm.totalInfectious[pi] > self.pm.startLD[pi]*self.pm.sizes[pi] and self.pm.lockdownON[pi] == 0:
            self.pm.contactDensity[pi] = self.pm.contactDensityAfterLockdown[pi]
            self.pm.swapLockdown += 1
            self.pm.lockdownON[pi] = 1
            self.UpdateAllRates()
        if self.pm.totalInfectious[pi] < self.pm.endLD[pi]*self.pm.sizes[pi] and self.pm.lockdownON[pi] == 1:
            self.pm.contactDensity[pi] = self.pm.contactDensityBeforeLockdown[pi]
            self.pm.swapLockdown += 1
            self.pm.lockdownON[pi] = 0
            self.UpdateAllRates()

    def Error(self, text):
        print(text)
        sys.exit(1)

    def create_list_haplotypes(self, haplotype):
        if haplotype.count("A") + haplotype.count("T") + haplotype.count("C") + haplotype.count("G") + haplotype.count("*") != self.sites:
            self.Error("Incorrect haplotype. Haplotype should contain only \"A\", \"T\", \"C\", \"G\", \"*\" and lenght of haplotype should be equal number of mutations sites.")

        haplotypes = [haplotype]
        for s in range(self.sites):
            for i in range(len(haplotypes)):
                haplotype_old = haplotypes[i]
                if haplotype_old[s] == "*":
                    haplotype = haplotype_old.replace("*", "A", 1)
                    haplotypes.append(haplotype)
                    haplotype = haplotype_old.replace("*", "T", 1)
                    haplotypes.append(haplotype)
                    haplotype = haplotype_old.replace("*", "C", 1)
                    haplotypes.append(haplotype)
                    haplotype = haplotype_old.replace("*", "G", 1)
                    haplotypes.append(haplotype)
        for i in range(len(haplotypes)-1, -1, -1):
            if haplotypes[i].count("*") != 0:
                haplotypes.remove(haplotypes[i])
        for i in range(len(haplotypes)):
            haplotypes[i] = self.calculate_haplotype(haplotypes[i])

        return haplotypes

    def set_tau(self, tau_l):
        self.tau_l = tau_l

    def set_transmission_rate(self, rate, haplotype):
        if isinstance(rate, (int, float)) == False:
            self.Error("Incorrect type of infection rate. Value should be int or float.")
        if rate<0:
            self.Error("Incorrect value of infection rate. Value should be more or equal 0.")

        if isinstance(haplotype, str):
            haplotypes = self.create_list_haplotypes(haplotype)
            for haplotype in haplotypes:
                self.bRate[haplotype] = rate
        elif isinstance(haplotype, int):
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")

            self.bRate[haplotype] = rate
        elif haplotype == None:
            for hn in range(self.hapNum):
                self.bRate[hn] = rate
        else:
            self.Error("Incorrect value of haplotype. Value should be string or int or None.")

    def set_recovery_rate(self, rate, haplotype):
        if isinstance(rate, (int, float)) == False:
            self.Error("Incorrect type of uninfection rate. Value should be int or float.")
        if rate<0:
            self.Error("Incorrect value of uninfection rate. Value should be more or equal 0.")

        if isinstance(haplotype, str):
            haplotypes = self.create_list_haplotypes(haplotype)
            for haplotype in haplotypes:
                self.dRate[haplotype] = rate
        elif isinstance(haplotype, int):
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")

            self.dRate[haplotype] = rate
        elif haplotype == None:
            for hn in range(self.hapNum):
                self.dRate[hn] = rate
        else:
            self.Error("Incorrect value of haplotype. Value should be string or int or None.")

    def set_sampling_rate(self, rate, haplotype):
        if self.sampling_probability == True:
            if isinstance(rate, (int, float)) == False:
                self.Error("Incorrect type of sampling probability. Value should be int or float.")
            if rate<0 or rate>1:
                self.Error("Incorrect value of sampling probability. Value should be more or equal 0 and less or equal 1.")

            if isinstance(haplotype, str):
                haplotypes = self.create_list_haplotypes(haplotype)
                for haplotype in haplotypes:
                    deathRate = self.dRate[haplotype]
                    self.dRate[haplotype] = (1-rate) * deathRate
                    self.sRate[haplotype] = rate * deathRate
            elif isinstance(haplotype, int):
                if haplotype<0 or haplotype>=self.hapNum:
                    self.Error("There are no such haplotype!")

                deathRate = self.dRate[haplotype]
                self.dRate[haplotype] = (1-rate) * deathRate
                self.sRate[haplotype] = rate * deathRate
            elif haplotype == None:
                for hn in range(self.hapNum):
                    deathRate = self.dRate[hn]
                    self.dRate[hn] = (1-rate) * deathRate
                    self.sRate[hn] = rate * deathRate
            else:
                self.Error("Incorrect value of haplotype. Value should be string or int or None.")

        elif self.sampling_probability == False:
            if isinstance(rate, (int, float)) == False:
                self.Error("Incorrect type of sampling rate. Value should be int or float.")
            if rate<0:
                self.Error("Incorrect value of sampling rate. Value should be more or equal 0.")

            if isinstance(haplotype, str):
                haplotypes = self.create_list_haplotypes(haplotype)
                for haplotype in haplotypes:
                    self.sRate[haplotype] = rate
            elif isinstance(haplotype, int):
                if haplotype<0 or haplotype>=self.hapNum:
                    self.Error("There are no such haplotype!")

                self.sRate[haplotype] = rate
            elif haplotype == None:
                for hn in range(self.hapNum):
                    self.sRate[hn] = rate
            else:
                self.Error("Incorrect value of haplotype. Value should be string or int or None.")
        else:
            self.Error("#TODO")

    def set_mutation_rate(self, rate, probabilities, haplotype, mutation):
        if isinstance(rate, (int, float)) and isinstance(probabilities, list) and isinstance(haplotype, str) and isinstance(mutation,int):#DONE
            if rate<0:
                self.Error("#TODO")
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            haplotypes = self.create_list_haplotypes(haplotype)
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            for haplotype in haplotypes:
                probabilities_allele = list(probabilities)
                del probabilities_allele[self.calculate_allele(haplotype, mutation)]
                if sum(probabilities_allele) == 0:
                    self.Error("#TODO")
                self.mRate[haplotype, mutation] = rate
                self.hapMutType[haplotype, mutation, 0] = probabilities_allele[0]
                self.hapMutType[haplotype, mutation, 1] = probabilities_allele[1]
                self.hapMutType[haplotype, mutation, 2] = probabilities_allele[2]
                self.totalHapMutType[haplotype, mutation] = sum(probabilities_allele)
        elif rate==None and isinstance(probabilities, list) and isinstance(haplotype, str) and isinstance(mutation,int):#DONE
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            haplotypes = self.create_list_haplotypes(haplotype)
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            for haplotype in haplotypes:
                probabilities_allele = list(probabilities)
                del probabilities_allele[self.calculate_allele(haplotype, mutation)]
                if sum(probabilities_allele) == 0:
                    self.Error("#TODO")
                self.hapMutType[haplotype, mutation, 0] = probabilities_allele[0]
                self.hapMutType[haplotype, mutation, 1] = probabilities_allele[1]
                self.hapMutType[haplotype, mutation, 2] = probabilities_allele[2]
                self.totalHapMutType[haplotype, mutation] = sum(probabilities_allele)
        elif isinstance(rate, (int, float)) and probabilities==None and isinstance(haplotype, str) and isinstance(mutation,int):#DONE
            if rate<0:
                self.Error("#TODO")
            haplotypes = self.create_list_haplotypes(haplotype)
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            for haplotype in haplotypes:
                self.mRate[haplotype, mutation] = rate
        elif isinstance(rate, (int, float)) and isinstance(probabilities, list) and isinstance(haplotype, int) and isinstance(mutation,int):#DONE
            if rate<0:
                self.Error("#TODO")
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            del probabilities[self.calculate_allele(haplotype, mutation)]
            if sum(probabilities) == 0:
                self.Error("#TODO")
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            self.mRate[haplotype, mutation] = rate
            self.hapMutType[haplotype, mutation, 0] = probabilities[0]
            self.hapMutType[haplotype, mutation, 1] = probabilities[1]
            self.hapMutType[haplotype, mutation, 2] = probabilities[2]
            self.totalHapMutType[haplotype, mutation] = sum(probabilities)
        elif rate==None and isinstance(probabilities, list) and isinstance(haplotype, int) and isinstance(mutation,int):#DONE
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            del probabilities[self.calculate_allele(haplotype, mutation)]
            if sum(probabilities) == 0:
                self.Error("#TODO")
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            self.hapMutType[haplotype, mutation, 0] = probabilities[0]
            self.hapMutType[haplotype, mutation, 1] = probabilities[1]
            self.hapMutType[haplotype, mutation, 2] = probabilities[2]
            self.totalHapMutType[haplotype, mutation] = sum(probabilities)
        elif isinstance(rate, (int, float)) and probabilities==None and isinstance(haplotype, int) and isinstance(mutation,int):#DONE
            if rate<0:
                self.Error("#TODO")
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            self.mRate[haplotype, mutation] = rate
        elif isinstance(rate, (int, float)) and isinstance(probabilities, list) and haplotype==None and isinstance(mutation,int):#DONE
            if rate<0:
                self.Error("#TODO")
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            for haplotype in range(self.hapNum):
                probabilities_allele = list(probabilities)
                del probabilities_allele[self.calculate_allele(haplotype, mutation)]
                if sum(probabilities_allele) == 0:
                    self.Error("#TODO")
                self.mRate[haplotype, mutation] = rate
                self.hapMutType[haplotype, mutation, 0] = probabilities_allele[0]
                self.hapMutType[haplotype, mutation, 1] = probabilities_allele[1]
                self.hapMutType[haplotype, mutation, 2] = probabilities_allele[2]
                self.totalHapMutType[haplotype, mutation] = sum(probabilities_allele)
        elif rate==None and isinstance(probabilities, list) and haplotype==None and isinstance(mutation,int):#DONE
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            for haplotype in range(self.hapNum):
                probabilities_allele = list(probabilities)
                del probabilities_allele[self.calculate_allele(haplotype, mutation)]
                if sum(probabilities_allele) == 0:
                    self.Error("#TODO")
                self.hapMutType[haplotype, mutation, 0] = probabilities_allele[0]
                self.hapMutType[haplotype, mutation, 1] = probabilities_allele[1]
                self.hapMutType[haplotype, mutation, 2] = probabilities_allele[2]
                self.totalHapMutType[haplotype, mutation] = sum(probabilities_allele)
        elif isinstance(rate, (int, float)) and probabilities==None and haplotype==None and isinstance(mutation,int):#DONE
            if rate<0:
                self.Error("#TODO")
            if mutation<0 or mutation>=self.sites:
                self.Error("There are no such mutation!")

            for haplotype in range(self.hapNum):
                self.mRate[haplotype, mutation] = rate
        elif isinstance(rate, (int, float)) and isinstance(probabilities, list) and isinstance(haplotype, str) and mutation==None:
            if rate<0:
                self.Error("#TODO")
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            haplotypes = self.create_list_haplotypes(haplotype)

            for haplotype in haplotypes:
                for s in range(self.sites):
                    probabilities_allele = list(probabilities)
                    del probabilities_allele[self.calculate_allele(haplotype, mutation)]
                    if sum(probabilities_allele) == 0:
                        self.Error("#TODO")

                    self.mRate[haplotype, s] = rate
                    self.hapMutType[haplotype, s, 0] = probabilities_allele[0]
                    self.hapMutType[haplotype, s, 1] = probabilities_allele[1]
                    self.hapMutType[haplotype, s, 2] = probabilities_allele[2]
                    self.totalHapMutType[haplotype, s] = sum(probabilities_allele)
        elif rate==None and isinstance(probabilities, list) and isinstance(haplotype, str) and mutation==None:#DONE
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            haplotypes = self.create_list_haplotypes(haplotype)

            for haplotype in haplotypes:
                for s in range(self.sites):
                    probabilities_allele = list(probabilities)
                    del probabilities_allele[self.calculate_allele(haplotype, mutation)]
                    if sum(probabilities_allele) == 0:
                        self.Error("#TODO")
                    self.hapMutType[haplotype, s, 0] = probabilities_allele[0]
                    self.hapMutType[haplotype, s, 1] = probabilities_allele[1]
                    self.hapMutType[haplotype, s, 2] = probabilities_allele[2]
                    self.totalHapMutType[haplotype, s] = sum(probabilities_allele)
        elif isinstance(rate, (int, float)) and probabilities==None and isinstance(haplotype, str) and mutation==None:
            if rate<0:
                self.Error("#TODO")
            haplotypes = self.create_list_haplotypes(haplotype)

            for haplotype in haplotypes:
                for s in range(self.sites):
                    self.mRate[haplotype, s] = rate
        elif isinstance(rate, (int, float)) and isinstance(probabilities, list) and isinstance(haplotype, int) and mutation==None:#DONE
            if rate<0:
                self.Error("#TODO")
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            del probabilities[self.calculate_allele(haplotype, mutation)]
            if sum(probabilities) == 0:
                self.Error("#TODO")
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")

            for s in range(self.sites):
                self.mRate[haplotype, s] = rate
                self.hapMutType[haplotype, s, 0] = probabilities[0]
                self.hapMutType[haplotype, s, 1] = probabilities[1]
                self.hapMutType[haplotype, s, 2] = probabilities[2]
                self.totalHapMutType[haplotype, s] = sum(probabilities)
        elif rate==None and isinstance(probabilities, list) and isinstance(haplotype, int) and mutation==None:#DONE
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")
            del probabilities[self.calculate_allele(haplotype, mutation)]
            if sum(probabilities) == 0:
                self.Error("#TODO")
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")

            for s in range(self.sites):
                self.hapMutType[haplotype, s, 0] = probabilities[0]
                self.hapMutType[haplotype, s, 1] = probabilities[1]
                self.hapMutType[haplotype, s, 2] = probabilities[2]
                self.totalHapMutType[haplotype, s] = sum(probabilities)
        elif isinstance(rate, (int, float)) and probabilities==None and isinstance(haplotype, int) and mutation==None:#DONE
            if rate<0:
                self.Error("#TODO")
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")

            for s in range(self.sites):
                self.mRate[haplotype, s] = rate
        elif isinstance(rate, (int, float)) and isinstance(probabilities, list) and haplotype==None and mutation==None:#DONE
            if rate<0:
                self.Error("#TODO")
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")

            for hn in range(self.hapNum):
                for s in range(self.sites):
                    probabilities_allele = list(probabilities)
                    del probabilities_allele[self.calculate_allele(hn, s)]
                    if sum(probabilities_allele) == 0:
                        self.Error("#TODO")
                    self.mRate[hn, s] = rate
                    self.hapMutType[hn, s, 0] = probabilities_allele[0]
                    self.hapMutType[hn, s, 1] = probabilities_allele[1]
                    self.hapMutType[hn, s, 2] = probabilities_allele[2]
                    self.totalHapMutType[hn, s] = sum(probabilities_allele)
        elif rate==None and isinstance(probabilities, list) and haplotype==None and mutation==None:#DONE
            if len(probabilities)!=4:
                self.Error("#TODO")
            for i in range(4):
                if isinstance(probabilities[i], (int, float)) == False:
                    self.Error("#TODO")
                if probabilities[i]<0:
                    self.Error("#TODO")

            for hn in range(self.hapNum):
                for s in range(self.sites):
                    probabilities_allele = list(probabilities)
                    del probabilities_allele[self.calculate_allele(hn, s)]
                    if sum(probabilities_allele) == 0:
                        self.Error("#TODO")
                    self.hapMutType[hn, s, 0] = probabilities_allele[0]
                    self.hapMutType[hn, s, 1] = probabilities_allele[1]
                    self.hapMutType[hn, s, 2] = probabilities_allele[2]
                    self.totalHapMutType[hn, s] = sum(probabilities_allele)
        elif isinstance(rate, (int, float)) and probabilities==None and haplotype==None and mutation==None:#DONE
            if rate<0:
                self.Error("#TODO")

            for hn in range(self.hapNum):
                for s in range(self.sites):
                    self.mRate[hn, s] = rate
        else:
            self.Error("#TODO")

    def set_contact_density(self, value, population):
        if isinstance(value, (int, float)) == False:
            self.Error("Incorrect type of contact density. Value should be int or float.")
        if value<0:
            self.Error("Incorrect value of contact density. Value should be more or equal 0.")

        if isinstance(population, int):
            if population<0 or population>=self.popNum:
                self.Error("There are no such population!")

            self.pm.contactDensity[population] = value
            self.pm.contactDensityBeforeLockdown[population] = value
        elif population == None:
            for pn in range(self.popNum):
                self.pm.contactDensity[pn] = value
                self.pm.contactDensityBeforeLockdown[pn] = value
        else:
            self.Error("Incorrect value of population. Value should be int or None.")

    def set_population_size(self, amount, population):
        if isinstance(amount, int) == False:
            self.Error("Incorrect value of amount. Value should be int.")
        if amount<0:
                self.Error("#TODO")

        if isinstance(population, int):
            if population<0 or population>=self.popNum:
                self.Error("There are no such population!")

            self.pm.sizes[population] = amount
            self.pm.totalSusceptible[population] = amount
            for sn in range(self.susNum):
                self.pm.susceptible[population, 0] = amount
        elif population==None:
            for pn in range(self.popNum):
                self.pm.sizes[pn] = amount
                self.pm.totalSusceptible[pn] = amount
                for sn in range(self.susNum):
                    self.pm.susceptible[pn, 0] = amount
        else:
            self.Error("Incorrect value of population. Value should be int or None.")

    def set_lockdown(self, parameters, population):
        if isinstance(parameters, list) == False:
            self.Error("#TODO")
        if len(parameters) != 3:
            self.Error("#TODO")
        if parameters[0]<0:
            self.Error("#TODO")
        if parameters[1]<0:
            self.Error("#TODO")
        if parameters[2]<0:
            self.Error("#TODO")

        if isinstance(population, int):
            if population<0 or population>=self.popNum:
                self.Error("There are no such population!")

            self.pm.contactDensityAfterLockdown[population] = parameters[0]
            self.pm.startLD[population] = parameters[1]
            self.pm.endLD[population] = parameters[2]
        elif population == None:
            for pn in range(self.popNum):
                self.pm.contactDensityAfterLockdown[pn] = parameters[0]
                self.pm.startLD[pn] = parameters[1]
                self.pm.endLD[pn] = parameters[2]
        else:
            self.Error("#TODO")

    def set_sampling_multiplier(self, multiplier, population):
        if isinstance(multiplier, (int, float)) == False:
            self.Error("Incorrect type of multiplier. Value should be int or float.")
        if multiplier<0:
            self.Error("Incorrect value of multiplier. Value should be more or equal 0.")

        if isinstance(population, int):
            if population<0 or population>=self.popNum:
                self.Error("There are no such population!")

            self.pm.samplingMultiplier[population] = multiplier
        elif population == None:
            for pn in range(self.popNum):
                self.pm.samplingMultiplier[pn] = multiplier
        else:
            self.Error("Incorrect value of population. Value should be int or None.")

    def set_migration_probability(self, probability, total_probability, source, target):
        if isinstance(probability, float) == True:
            if probability<0 or probability>1:
                self.Error("Incorrect probability. Value should be between 0 and 1!")

            if isinstance(source, int) and isinstance(target, int):
                if source<0 or source>=self.popNum:
                    self.Error("There are no such population!")
                if target<0 or target>=self.popNum:
                    self.Error("There are no such population!")
                if source==target:
                    self.Error("Source and target population shouldn't be equal!")

                self.pm.migrationRates[source, target] = probability
                summa = 0
                for pn in range(self.popNum):
                    summa += self.pm.migrationRates[source, pn]
                if summa > 1:
                    self.Error("#TODO")
            elif source==None and isinstance(target, int):
                if target<0 or target>=self.popNum:
                    self.Error("There are no such population!")

                for pn1 in range(self.popNum):
                    if pn1 != target:
                        self.pm.migrationRates[pn1, target] = probability
                    summa = 0
                    for pn2 in range(self.popNum):
                        summa += self.pm.migrationRates[pn1, pn2]
                    if summa > 1:
                        self.Error("#TODO")
            elif isinstance(source, int) and target==None:
                if source<0 or source>=self.popNum:
                    self.Error("There are no such population!")

                for pn2 in range(self.popNum):
                    if source != pn2:
                        self.pm.migrationRates[source, pn2] = probability
                summa = 0
                for pn in range(self.popNum):
                    summa += self.pm.migrationRates[source, pn]
                if summa > 1:
                    self.Error("#TODO")
            elif source==None and target==None:
                for pn1 in range(self.popNum):
                    for pn2 in range(self.popNum):
                        if pn1 != pn2:
                            self.pm.migrationRates[pn1, pn2] = probability
                    summa = 0
                    for pn2 in range(self.popNum):
                        summa += self.pm.migrationRates[pn1, pn2]
                    if summa > 1:
                        self.Error("#TODO")
            else:
                self.Error("Incorrect value of population. Value should be int or None.")
        elif isinstance(total_probability, float) == True:
            if total_probability<0 or total_probability>1:
                self.Error("Incorrect total probability. Value should be between 0 and 1!")

            for pn1 in range(self.popNum):
                for pn2 in range(self.popNum):
                    if pn1 != pn2:
                        self.pm.migrationRates[pn1, pn2] = total_probability/(self.popNum-1)
        else:
            self.Error("#TODO")

    def set_susceptible_individuals(self, amount, source_type, target_type, population):
        if isinstance(amount, int) == False:
            self.Error("Incorrect value of amount. Value should be int.")
        if isinstance(source_type, int) == False:
            self.Error("Incorrect value of source susceptibility type. Value should be int.")
        if isinstance(target_type, int) == False:
            self.Error("Incorrect value of target susceptibility type. Value should be int.")
        if source_type<0 or source_type>=self.susNum:
            self.Error("There are no such susceptibility type!")
        if target_type<0 or target_type>=self.susNum:
            self.Error("There are no such susceptibility type!")
        if source_type==target_type:
            self.Error("Source and target susceptibility type shouldn't be equal!")

        if isinstance(population, int):
            if population<0 or population>=self.popNum:
                self.Error("There are no such population!")
            if amount<0 or amount>self.pm.susceptible[population, source_type]:
                self.Error("#TODO")

            self.pm.susceptible[population, source_type] -= amount
            self.pm.susceptible[population, target_type] += amount
        elif population==None:
            for pn in range(self.popNum):
                if amount<0 or amount>self.pm.susceptible[pn, source_type]:
                    self.Error("#TODO")
                self.pm.susceptible[pn, source_type] -= amount
                self.pm.susceptible[pn, target_type] += amount
        else:
            self.Error("Incorrect value of population. Value should be int or None.")

    def set_susceptibility_type(self, susceptibility_type, haplotype):
        if isinstance(susceptibility_type, int) == False:
            self.Error("Incorrect value of susceptibility type. Value should be int.")
        if susceptibility_type<0 or susceptibility_type>=self.susNum:
            self.Error("There are no such susceptibility type!")

        if isinstance(haplotype, str):
            haplotypes = self.create_list_haplotypes(haplotype)
            for haplotype in haplotypes:
                self.suscType[haplotype] = susceptibility_type
        elif isinstance(haplotype, int):
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")

            self.suscType[haplotype] = susceptibility_type
        elif haplotype == None:
            for hn in range(self.hapNum):
                self.suscType[hn] = susceptibility_type
        else:
            self.Error("Incorrect value of haplotype. Value should be int or str or None.")

    def set_susceptibility(self, rate, haplotype, susceptibility_type):
        if isinstance(rate, (int, float)) == False:
            self.Error("Incorrect value of susceptibility rate. Value should be int or float.")
        if rate<0:
            self.Error("Incorrect value of susceptibility rate. Value should be more or equal 0.")

        if isinstance(haplotype, str) and isinstance(susceptibility_type, int):
            haplotypes = self.create_list_haplotypes(haplotype)
            if susceptibility_type<0 or susceptibility_type>=self.susNum:
                self.Error("There are no such susceptibility type!")

            for haplotype in haplotypes:
                self.susceptibility[haplotype, susceptibility_type] = rate
        elif isinstance(haplotype, int) and isinstance(susceptibility_type, int):
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")
            if susceptibility_type<0 or susceptibility_type>=self.susNum:
                self.Error("There are no such susceptibility type!")

            self.susceptibility[haplotype, susceptibility_type] = rate
        elif haplotype==None and isinstance(susceptibility_type, int):
            if susceptibility_type<0 or susceptibility_type>=self.susNum:
                self.Error("There are no such susceptibility type!")

            for hn in range(self.hapNum):
                self.susceptibility[hn, susceptibility_type] = rate
        elif isinstance(haplotype, str) and susceptibility_type==None:
            haplotypes = self.create_list_haplotypes(haplotype)

            for haplotype in haplotypes:
                for sn in range(self.susNum):
                    self.susceptibility[haplotype, sn] = rate
        elif isinstance(haplotype, int) and susceptibility_type==None:
            if haplotype<0 or haplotype>=self.hapNum:
                self.Error("There are no such haplotype!")

            for sn in range(self.susNum):
                self.susceptibility[haplotype, sn] = rate
        elif haplotype==None and susceptibility_type==None:
            for hn in range(self.hapNum):
                for sn in range(self.susNum):
                    self.susceptibility[hn, sn] = rate
        else:
            self.Error("Incorrect value of haplotype or susceptibility rate. Value should be int or None.")

    def set_immunity_transition(self, rate, source, target):
        if isinstance(rate, (int, float)) == False:
            self.Error("Incorrect value of rate. Value should be int or float.")
        if rate<0:
            self.Error("Incorrect value of rate. Value should be more or equal 0.")

        if isinstance(source, int) and isinstance(target, int):
            if source<0 or source>=self.susNum:
                self.Error("There are no such source susceptibility type!")
            if target<0 or target>=self.susNum:
                self.Error("There are no such target susceptibility type!")
            if source==target:
                self.Error("Source and target susceptibility type shouldn't be equal!")

            self.suscepTransition[source, target] = rate
        elif source==None and isinstance(target, int):
            if target<0 or target>=self.susNum:
                self.Error("There are no such target susceptibility type!")

            for sn1 in range(self.susNum):
                if sn1 != target:
                        self.suscepTransition[sn1, target] = rate
        elif isinstance(source, int) and target==None:
            if source<0 or source>=self.susNum:
                self.Error("There are no such source susceptibility type!")

            for sn2 in range(self.susNum):
                if source != sn2:
                    self.suscepTransition[source, sn2] = rate
        elif source==None and target==None:
            for sn1 in range(self.susNum):
                for sn2 in range(self.susNum):
                    if sn1 != sn2:
                        self.suscepTransition[sn1, sn2] = rate
        else:
            self.Error("Incorrect value of source or target susceptibility type. Value should be int or None.")


    def print_basic_parameters(self):
        print("*****************")
        print("***Basic rates***")
        print("*****************")
        table = PrettyTable()

        field = ["H", "TR", "RR", "SR", "ST"]
        for s in range(self.sites):
            field.append("M" + str(s))
            field.append("MW" + str(s))
        table.field_names = field
        for hn in range(self.hapNum):
            list = ["\n" + self.calculate_string(hn), "\n" + str(self.bRate[hn]), "\n" + str(self.dRate[hn]), "\n" + str(self.sRate[hn]), "\n" + str(self.suscType[hn])]
            for s in range(self.sites):
                list.append("\n" + str(self.mRate[hn, s]))
                list.append(self.create_mutations(hn, s))
            table.add_row(list)

        print(table)
        print("Legend:")
        print("H - haplotype")
        print("TR - transmission rate")
        print("RR - recovery rate")
        print("SR - sampling rate")
        print("ST - susceptibility type")
        for s in range(self.sites):
            print("M" + str(s) + " - " + str(s) + " mutation rate")
            print("MW" + str(s) + " - " + str(s) + " mutation weights")
        print()

    def print_populations(self):
        print("*****************")
        print("***Populations***")
        print("*****************")
        table_populations = PrettyTable()

        table_populations.field_names = ["ID", "Size", "CD", "CDALD", "SLD", "ELD", "SM"]
        for pn in range(self.popNum):
            table_populations.add_row([pn, self.pm.sizes[pn], self.pm.contactDensity[pn], self.pm.contactDensityAfterLockdown[pn], self.pm.startLD[pn], self.pm.endLD[pn], self.pm.samplingMultiplier[pn]])

        print(table_populations)
        print("Legend:")
        print("ID - number of population")
        print("Size - size of population")
        print("CD - contact density")
        print("CDALD - contact density at lockdown")
        print("SLD - start of lockdown")
        print("ELD - end of lockdown")
        print("SM - sampling multiplier")
        print()

        print("*****************")
        print("***Susceptible***")
        print("*****************")
        table_susceptible = PrettyTable()

        field = ["ST\\ID"]
        for pn in range(self.popNum):
            field.append(pn)
        for sn in range(self.susNum):
            row = [sn]
            for pn in range(self.popNum):
                row.append(self.pm.susceptible[pn, sn])
            table_susceptible.add_row(row)
        table_susceptible.field_names = field

        print(table_susceptible)
        print("Legend:")
        print("ID - ID population")
        print("ST - susceptibility type")
        print()

        print("**********************")
        print("***Migration matrix***")
        print("**********************")
        table_migration = PrettyTable()

        field = ["S\\T"]
        for pn1 in range(self.popNum):
            field.append(pn1)
            row = [pn1]
            for pn2 in range(self.popNum):
                row.append(self.pm.migrationRates[pn1, pn2])
            table_migration.add_row(row)
        table_migration.field_names = field

        print(table_migration)
        print("Legend:")
        print("S - ID source population")
        print("T - ID target population")
        print()

    def print_immunity_model(self):
        print("********************")
        print("***Immunity model***")
        print("********************")
        table_immunity = PrettyTable()

        field = ["H\\ST"]
        for sn in range(self.susNum):
            field.append("S" + str(sn))
        table_immunity.field_names = field
        for hn in range(self.hapNum):
            row = [self.calculate_string(hn)]
            for sn in range(self.susNum):
                row.append(self.susceptibility[hn, sn])
            table_immunity.add_row(row)

        print(table_immunity)
        print("Legend:")
        print("H - haplotype")
        print("ST - susceptibility type")
        print()

        print("*******************************")
        print("***Immunity transition rates***")
        print("*******************************")
        table_immunity_transition = PrettyTable()

        field = ["ID"]
        for sn1 in range(self.susNum):
            field.append(sn1)
            row = [sn1]
            for sn2 in range(self.susNum):
                row.append(self.suscepTransition[sn1, sn2])
            table_immunity_transition.add_row(row)
        table_immunity_transition.field_names = field

        print(table_immunity_transition)
        print("Legend:")
        print("ID - ID susceptibility type")
        print()

    def output_parameters(self, name_file):
        if not os.path.isdir("parameters_" + str(name_file)):
            os.mkdir("parameters_" + str(name_file))
        with open(name_file + ".rt", "w") as file:
            file.write("#Rates_format_version 0.0.1\nH B D S")
            for s in range(self.sites):
                file.write(" M" + str(s))
            file.write("\n")
            for hn in range(self.hapNum):
                file.write(self.calculate_haplotype(hn) + " " + str(self.bRate[hn]) + " " + str(self.dRate[hn]) + " " + str(self.sRate[hn]))
                for s in range(self.sites):
                    file.write(str(self.mRate[hn, s]) + "," + str(self.hapMutType[hn, s, 0]) + "," + str(self.hapMutType[hn, s, 1]) + "," + str(self.hapMutType[hn, s, 2]) + " ")
                file.write("\n")

        with open(name_file + ".pp", "w") as file:
            file.write("#Population_format_version 0.0.1\nid size contactDensity conDenAfterLD startLD endLD samplingMulriplier")
            for pn in range(self.popNum):
                file.write(str(pn) + " " + self.pm.sizes[pn] + " " + self.pm.contactDensity[pn] + " " + self.pm.contactDensityAfterLockdown[pn] + " " + self.pm.startLD[pn] + " " + self.pm.endLD[pn] + " " + self.pm.samplingMultiplier[pn] + "\n")

        with open(name_file + ".mg", "w") as file:
            file.write("#Migration_format_version 0.0.1\n")
            for pn1 in range(self.popNum):
                for pn2 in range(self.popNum):
                    file.write(str(self.pm.migrationRates[pn1, pn2]) + " ")
                file.write("\n")

        with open(name_file + ".su", "w") as file:
            file.write("#Susceptibility_format_version 0.0.1\nH T")
            for sn in range(self.susNum):
                file.write(" S" + str(sn))
            file.write("\n")
            for hn in range(self.hapNum):
                file.write(self.calculate_haplotype(hn) + " " + str(self.suscType[hn]))
                for sn in range(self.susNum):
                    file.write(" " + str(self.susceptibility[hn, sn]))
                file.write("\n")

        with open(name_file + ".st", "w") as file:
            file.write("#Susceptibility_format_version 0.0.1\n")
            for sn1 in range(self.susNum):
                for sn2 in range(self.susNum):
                    file.write(self.suscepTransition[sn1, sn2] + " ")
                file.write("\n")

    def create_mutations(self, haplotype, site):
        hap = self.calculate_string(haplotype)
        haplotypes = [hap[:site] + "A" + hap[site+1:], hap[:site] + "T" + hap[site+1:], hap[:site] + "C" + hap[site+1:], hap[:site] + "G" + hap[site+1:]]
        for i in range(4):
            if haplotypes[i] == hap:
                haplotypes.remove(haplotypes[i])
                haplotypes.append(hap)
                break
        color_hap=[]
        for hapl in haplotypes:
            a = ""
            for s in range(self.sites):
                if s == site:
                    a = a + "\033[31m{}\033[0m" .format(hapl[s:s+1])
                else:
                    a = a + hapl[s:s+1]
            color_hap.append(a)
        string = color_hap[3] + "->" + color_hap[0] + ": " + str(self.hapMutType[haplotype, site, 0]) + "\n" + color_hap[3] + "->" + color_hap[1] + ": " + str(self.hapMutType[haplotype, site, 1]) + "\n" + color_hap[3] + "->" + color_hap[2] + ": " + str(self.hapMutType[haplotype, site, 2]) + "\n"
        return string

        self.hapMutType[hn, s, 0]

    def calculate_string(self, hapNum):
        letters = ["A", "T", "C", "G"]
        string = ""
        for s in range(self.sites):
            string = letters[hapNum%4] + string
            hapNum = hapNum // 4
        return string

    def calculate_haplotype(self, string):
        string = string[::-1]
        haplotype = 0
        for s in range(self.sites):
            if string[s]=="T":
                haplotype += (4**s)
            elif string[s]=="C":
                haplotype += 2*(4**s)
            elif string[s]=="G":
                haplotype += 3*(4**s)
        return haplotype

    def calculate_allele(self, haplotype, site):
        for _ in range(self.sites-site):
            allele = haplotype % 4
            haplotype = haplotype // 4
        return allele

    def get_sites(self):
        return self.sites

    def get_hapNum(self):
        return self.hapNum

    def get_popNum(self):
        return self.popNum

    def get_susNum(self):
        return self.susNum

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cpdef GetGenealogy(self, seed):
        cdef:
            Py_ssize_t ptrTreeAndTime, n1, n2, id1, id2, id3, lbs, lbs_e, ns, nt, idt, ids, lbss
            double p
            vector[vector[vector[Py_ssize_t]]] liveBranchesS
            vector[vector[Py_ssize_t]] vecint2
            vector[Py_ssize_t] vecint1

            double e_time
            Py_ssize_t e_type_, e_population, e_haplotype, e_newHaplotype, e_newPopulation

        if self.sCounter < 2: #TODO if number of sampled leaves is 0 (probably 1 as well), then GetGenealogy seems to go to an infinite cycle
            print("Less than two cases were sampled...")
            print("_________________________________")
            sys.exit(0)

        if seed != None:
            self.rndm = RndmWrapper(seed=(seed, 0))

        ptrTreeAndTime = 0
        self.tree = np.zeros(2 * self.sCounter - 1, dtype=np.int64)
        self.times = np.zeros(2 * self.sCounter - 1, dtype=float)

        for i in range( self.popNum ):
            liveBranchesS.push_back(vecint2)
            for _ in range( self.hapNum ):
                liveBranchesS[i].push_back(vecint1)

        for e_id in range(self.events.ptr-1, -1, -1):
            # this event
            e_time = self.events.times[e_id]
            e_type_ = self.events.types[e_id]
            e_haplotype = self.events.haplotypes[e_id]
            e_population = self.events.populations[e_id]
            e_newHaplotype = self.events.newHaplotypes[e_id]
            e_newPopulation = self.events.newPopulations[e_id]
            if e_type_ == BIRTH:
                lbs = liveBranchesS[e_population][e_haplotype].size()
                lbs_e = self.pm.liveBranches[e_population, e_haplotype]
                p = float(lbs)*(float(lbs)-1.0)/ float(lbs_e) / (float(lbs_e) - 1.0)
                if self.rndm.uniform() < p:
                    n1 = int(floor( lbs*self.rndm.uniform() ))
                    n2 = int(floor( (lbs-1)*self.rndm.uniform() ))
                    if n2 >= n1:
                        n2 += 1
                    id1 = liveBranchesS[e_population][e_haplotype][n1]
                    id2 = liveBranchesS[e_population][e_haplotype][n2]
                    id3 = ptrTreeAndTime
                    liveBranchesS[e_population][e_haplotype][n1] = id3
                    liveBranchesS[e_population][e_haplotype][n2] = liveBranchesS[e_population][e_haplotype][lbs-1]
                    liveBranchesS[e_population][e_haplotype].pop_back()
                    self.tree[id1] = id3
                    self.tree[id2] = id3
                    self.tree[ptrTreeAndTime] = -1
                    self.times[ptrTreeAndTime] = e_time
                    ptrTreeAndTime += 1
                self.pm.liveBranches[e_population, e_haplotype] -= 1
            elif e_type_ == DEATH:
                self.pm.liveBranches[e_population, e_haplotype] += 1
            elif e_type_ == SAMPLING:
                self.pm.liveBranches[e_population, e_haplotype] += 1
                liveBranchesS[e_population][e_haplotype].push_back( ptrTreeAndTime )
                self.tree[ptrTreeAndTime] = -1
                self.times[ptrTreeAndTime] = e_time
                ptrTreeAndTime += 1
            elif e_type_ == MUTATION:
                lbs = liveBranchesS[e_population][e_newHaplotype].size()
                p = float(lbs)/self.pm.liveBranches[e_population, e_newHaplotype]
                if self.rndm.uniform() < p:
                    n1 = int(floor( lbs*self.rndm.uniform() ))
                    id1 = liveBranchesS[e_population][e_newHaplotype][n1]
                    liveBranchesS[e_population][e_newHaplotype][n1] = liveBranchesS[e_population][e_newHaplotype][lbs-1]
                    liveBranchesS[e_population][e_newHaplotype].pop_back()
                    liveBranchesS[e_population][e_haplotype].push_back(id1)
                    self.mut.AddMutation(id1, e_haplotype, e_newHaplotype, e_time)
                self.pm.liveBranches[e_population, e_newHaplotype] -= 1
                self.pm.liveBranches[e_population, e_haplotype] += 1
            elif e_type_ == SUSCCHANGE:
                pass
            elif e_type_ == MIGRATION:
                lbs = liveBranchesS[e_newPopulation][e_haplotype].size()
                p = float(lbs)/self.pm.liveBranches[e_newPopulation][e_haplotype]
                if self.rndm.uniform() < p:
                    nt = int(floor( lbs*self.rndm.uniform() ))
                    lbss = liveBranchesS[e_population][e_haplotype].size()
                    p1 = float(lbss)/self.pm.liveBranches[e_population, e_haplotype]
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
                        self.pm.mig.AddMigration(idt, e_time, e_population, e_newPopulation)
                    else:
                        liveBranchesS[e_population][e_haplotype].push_back(liveBranchesS[e_newPopulation][e_haplotype][nt])
                        liveBranchesS[e_newPopulation][e_haplotype][nt] = liveBranchesS[e_newPopulation][e_haplotype][lbs-1]
                        liveBranchesS[e_newPopulation][e_haplotype].pop_back()
                self.pm.liveBranches[e_newPopulation, e_haplotype] -= 1
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

    def LogDynamics(self, step_num, output_file):
        time_points = [i*self.currentTime/step_num for i in range(step_num+1)]
        suscepDate = np.zeros((self.popNum, self.susceptible_num), dtype=np.int64)
        hapDate = np.zeros((self.popNum, self.hapNum), dtype=np.int64)
        for i in range(self.popNum):
            for sn in range(self.susceptible_num):
                if sn == 0:
                    suscepDate[i, sn] = self.pm.sizes[i]
                else:
                    suscepDate[i, sn] = 0
            for hn in range(self.hapNum):
                hapDate[i, hn] = 0
        hapDate[0][0] += 1
        suscepDate[0][0] -= 1
        if output_file == True:
            if not os.path.isdir("logs"):
                os.mkdir("logs")
            logDynamics = []
            for i in range(self.popNum):
                logDynamics.append(open('logs/PID' + str(i) + '.log', 'w'))
                logDynamics[i].write("time")
                for sn in range(self.susceptible_num):
                    logDynamics[i].write(" S" + str(sn))
                for hn in range(self.hapNum):
                    logDynamics[i].write(" H" + str(hn))
                logDynamics[i].write("\n")
        else:
            log = dict()
            log["time"] = list()
            for i in range(self.popNum):
                log["P" + str(i)] = dict()
                for j  in range(self.susceptible_num):
                    log["P" + str(i)]["S" + str(j)] = list()
                for j  in range(self.hapNum):
                    log["P" + str(i)]["H" + str(j)] = list()

        point = 0
        for j in range(self.events.ptr):
            if self.events.types[j] == BIRTH:
                hapDate[self.events.populations[j], self.events.haplotypes[j]] += 1
                suscepDate[self.events.populations[j], self.events.newHaplotypes[j]] -= 1
            elif self.events.types[j] == DEATH:
                hapDate[self.events.populations[j], self.events.haplotypes[j]] -= 1
                suscepDate[self.events.populations[j], self.events.newHaplotypes[j]] += 1
            elif self.events.types[j] == SAMPLING:
                hapDate[self.events.populations[j], self.events.haplotypes[j]] -= 1
                suscepDate[self.events.populations[j], self.events.newHaplotypes[j]] += 1
            elif self.events.types[j] == MUTATION:
                hapDate[self.events.populations[j], self.events.haplotypes[j]] -= 1
                hapDate[self.events.populations[j], self.events.newHaplotypes[j]] += 1
            elif self.events.types[j] == SUSCCHANGE:
                suscepDate[self.events.populations[j], self.events.haplotypes[j]] -= 1
                suscepDate[self.events.populations[j], self.events.newHaplotypes[j]] += 1
            elif self.events.types[j] == MIGRATION:
                suscepDate[self.events.newPopulations[j], self.events.newHaplotypes[j]] -= 1
                hapDate[self.events.newPopulations[j], self.events.haplotypes[j]] += 1
            if time_points[point] <= self.events.times[j]:
                if output_file == True:
                    for i in range(self.popNum):
                        logDynamics[i].write(str(time_points[point]) + " ")
                        for k in range(self.susceptible_num):
                            logDynamics[i].write(str(suscepDate[i, k]) + " ")
                        for k in range(self.hapNum):
                            logDynamics[i].write(str(hapDate[i, k]) + " ")
                        logDynamics[i].write("\n")
                    point += 1
                else:
                    log["time"].append(time_points[point])
                    for i in range(self.popNum):
                        for j  in range(self.susceptible_num):
                            log["P" + str(i)]["S" + str(j)].append(suscepDate[i, j])
                        for j  in range(self.hapNum):
                            log["P" + str(i)]["H" + str(j)].append(hapDate[i, j])
                    point += 1

        if output_file == True:
            for i in range(self.popNum-1, -1, -1):
                logDynamics[i].close()
        else:
            return log

    def get_data_infectious(self, pop, hap, step_num):
        time_points = [i*self.currentTime/step_num for i in range(step_num+1)]
        Date = np.zeros(step_num+1)
        Sample = np.zeros(step_num+1)

        point = 1
        for j in range(self.events.ptr):
            if point != step_num and time_points[point] < self.events.times[j]:
                Date[point+1] = Date[point]
                Sample[point+1] = Sample[point]
                point += 1
            if self.events.populations[j] == pop and self.events.haplotypes[j] == hap:
                if self.events.types[j] == BIRTH:
                    Date[point] += 1
                elif self.events.types[j] == DEATH:
                    Date[point] -= 1
                elif self.events.types[j] == SAMPLING:
                    Date[point] -= 1
                    Sample[point] += 1
                elif self.events.types[j] == MUTATION:
                    Date[point] -= 1
            elif self.events.types[j] == MUTATION and self.events.newHaplotypes[j] == hap and self.events.populations[j] == pop:
                Date[point] += 1
            elif self.events.types[j] == MIGRATION and self.events.newPopulations[j] == pop and self.events.haplotypes[j] == hap:
                Date[point] += 1

        return Date, Sample, time_points

    def get_data_susceptible(self, pop, sus, step_num):
        time_points = [i*self.currentTime/step_num for i in range(step_num+1)]
        Date = np.zeros(step_num+1)
        if sus == 0:
            Date[0] = self.pm.sizes[pop]
            Date[1] = self.pm.sizes[pop]

        point = 1
        for j in range(self.events.ptr):
            if point != step_num and time_points[point] < self.events.times[j]:
                Date[point+1] = Date[point]
                point += 1
            if self.events.populations[j] == pop and self.events.newHaplotypes[j] == sus:
                if self.events.types[j] == BIRTH:
                    Date[point] -= 1
                elif self.events.types[j] == DEATH:
                    Date[point] += 1
                elif self.events.types[j] == SAMPLING:
                    Date[point] += 1
                elif self.events.types[j] == SUSCCHANGE:
                    Date[point] += 1
            elif self.events.types[j] == SUSCCHANGE and self.events.haplotypes[j] == sus and self.events.populations[j] == pop:
                Date[point] -= 1
            elif self.events.types[j] == MIGRATION and self.events.newPopulations[j] == pop and self.events.newHaplotypes[j] == sus:
                Date[point] -= 1

        return Date, time_points

    def sample_data(self):
        time, pop, hap = [], [], []
        for i in range(self.events.ptr):
            if self.events.types[i] == SAMPLING:
                time.append(self.events.times[i])
                pop.append(self.events.populations[i])
                hap.append(self.events.haplotypes[i])
        return time, pop, hap

    def Stats(self):
        print("Seed: ", self.seed)
        print("Number of samples:", self.sCounter)
        print("Total number of iterations: ", self.events.ptr)
        print("Size events: ", self.events.size)
        print("Current time: ", self.currentTime)

    def Debug(self):
        self.UpdateAllRates()
        print("Parameters")
        print("Mutations number(const): ", self.sites)
        print("Haplotypes number(const): ", self.hapNum)
        print("Populations number(const): ", self.popNum)
        print("Susceptible number(const): ", self.susNum)
        print("Samping probability(const): ", self.sampling_probability)
        print("Strong migration(const): ", self.strong_migration)

        print("Birth counter(mutable): ", self.bCounter)
        print("Death counter(mutable): ", self.dCounter)
        print("Sampling counter(mutable): ", self.sCounter)
        print("Mutation counter(mutable): ", self.mCounter)
        print("Immunity transition counter(mutable):", self.iCounter)

        print("Current time(mutable): ", self.currentTime)
        print("Seed(const): ", self.seed)
        print("Max effective birth(const): ", self.maxEffectiveBirth)
        print("Total rate(mutable): ", self.totalRate)
        print("Total migration rate(mutable): ", self.totalMigrationRate)
        print("Random number(mutable): ", self.rn)

        print("Susceptible type(const): ", sep=" ", end="")
        for hn in range(self.hapNum):
            print(self.suscType[hn], end=" ")
        print()
        print("Birth rate(const): ", sep="", end="")
        for hn in range(self.hapNum):
            print(self.bRate[hn], end=" ")
        print()
        print("Death rate(const): ", sep="", end="")
        for hn in range(self.hapNum):
            print(self.dRate[hn], end=" ")
        print()
        print("Sampling rate(const): ", sep="", end="")
        for hn in range(self.hapNum):
            print(self.sRate[hn], end=" ")
        print()
        print("Total mutation rate(const): ", sep="", end="")
        for hn in range(self.hapNum):
            print(self.tmRate[hn], end=" ")
        print()
        print("maxEffectiveBirthMigration(const): ", sep="", end="")
        for pn in range(self.popNum):
            print(self.maxEffectiveBirthMigration[pn], end=" ")
        print()
        print("Max susceptibility(const): ", end=" ")
        for hn in range(self.hapNum):
            print(self.maxSusceptibility[hn], end=" ")
        print()
        print("suscepCumulTransition(const): ", sep="", end="")
        for sn in range(self.susNum):
            print(self.suscepCumulTransition[sn], end=" ")
        print()
        print("infectPopRate(mutable): ", sep="", end="")
        for pn in range(self.popNum):
            print(self.infectPopRate[pn], end=" ")
        print()
        print("immunePopRate(mutable): ", sep="", end="")
        for pn in range(self.popNum):
            print(self.immunePopRate[pn], end=" ")
        print()
        print("Population rate(mutable): ", sep="", end="")
        for pn in range(self.popNum):
            print(self.popRate[pn], end=" ")
        print()
        print("Migration population rate(mutable): ", sep="", end="")
        for pn in range(self.popNum):
            print(self.migPopRate[pn], end=" ")
        print()

        print("Mutation rate(const)----")
        for hn in range(self.hapNum):
            for s in range(self.sites):
                print(self.mRate[hn, s], end=" ")
            print()
        print()
        print("Total haplotype mutation type(const)----")
        for hn in range(self.hapNum):
            for s in range(self.sites):
                print(self.totalHapMutType[hn, s], end=" ")
            print()
        print()
        print("Total event haplotype population rate(mutable)----")
        for pn in range(self.popNum):
            for hn in range(self.hapNum):
                print(self.tEventHapPopRate[pn, hn], end=" ")
            print()
        print()

        print("Susceptibility(const)----")
        for hn in range(self.hapNum):
            for sn in range(self.susNum):
                print(self.susceptibility[hn, sn], end=" ")
            print()
        print()
        print("suscepTransition(const)----")
        for sn1 in range(self.susNum):
            for sn2 in range(self.susNum):
                print(self.suscepTransition[sn1, sn2], end=" ")
            print()
        print()
        print("immuneSourcePopRate(mutable)----")
        for pn in range(self.popNum):
            for sn in range(self.susNum):
                print(self.immuneSourcePopRate[pn, sn], end=" ")
            print()
        print()
        print("Haplotypes populations rates(mutable)----")
        for pn in range(self.popNum):
            for hn in range(self.hapNum):
                print(self.hapPopRate[pn, hn], end=" ")
            print()
        print()

        print("hapMutType(const)----")
        for hn in range(self.hapNum):
            for s in range(self.sites):
                for i in range(3):
                    print(self.hapMutType[hn, s, i], end=" ")
                print()
            print()
        print()
        print("Event haplotypes populations rate(mutable)----")
        for pn in range(self.popNum):
            for hn in range(self.hapNum):
                for i in range(4):
                    print(self.eventHapPopRate[pn, hn, i], end=" ")
                print()
            print()
        print()
        print("Susceptible haplotypes populations rate(mutable)----")
        for pn in range(self.popNum):
            for hn in range(self.hapNum):
                for sn in range(self.susNum):
                    print(self.susceptHapPopRate[pn, hn, sn], end=" ")
                print()
            print()
        print()

        self.pm.debug()

    def output_tree_mutations(self):
        tree = []
        times = []
        for i in range(self.tree.shape[0]):
            tree.append(self.tree[i])
            times.append(self.times[i])
        mut = [[], [], [], [], []]
        for i in range(self.mut.nodeId.size()):
            mut[0].append(self.mut.nodeId[i])
            mut[1].append(self.mut.AS[i])
            mut[2].append(self.mut.site[i])
            mut[3].append(self.mut.DS[i])
            mut[4].append(self.mut.time[i])

        times_dict = {self.events.times[i]: i for i in range(len(self.events.times))}
        populations = {}
        for time in self.times:
            populations[time] = self.events.populations[times_dict[time]]

        return tree, times, mut, populations

    def get_chain_events(self, name_file):
        chain = [self.events.times, self.events.types, self.events.haplotypes, self.events.populations, self.events.newHaplotypes, self.events.newPopulations]
        if name_file == None:
            return chain
        else:
            np.savez(name_file, chain)

    def writeMigrations(self, name_file):
        #with open(name_file + '.mig', 'w') as file:
        file = open(name_file + '.mig', 'w')
        file.write("Node Time Old_population New_population\n")
        for i in range(self.pm.mig.nodeId.size()):
            file.write(str(self.pm.mig.nodeId[i]) + " " + str(self.pm.mig.time[i]) + " " + str(self.pm.mig.oldPop[i]) + " " + str(self.pm.mig.newPop[i]) + "\n")
        file.close()


    #############################
    ### TAU LEAPING ALGORITHM ###
    #############################

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef double MigrationPropensity(self, Py_ssize_t s, Py_ssize_t r, Py_ssize_t i, Py_ssize_t h):#TODO: use EffevtiveMigration
        cdef double prop
        prop = self.pm.migrationRates[r, s]*self.pm.contactDensity[s]/self.pm.effectiveSizes[s]
        prop += self.pm.migrationRates[s, r]*self.pm.contactDensity[r]/self.pm.effectiveSizes[r]
        prop *= self.pm.susceptible[r, i]*self.pm.liveBranches[s, h]*self.bRate[h]*self.susceptibility[h, i]*self.pm.migrationRates[s, s]
        return prop

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef Py_ssize_t PropensitiesNumber(self):
        cdef Py_ssize_t prop_num

        #Migrations
        prop_num = self.popNum*(self.popNum-1)*self.hapNum
        prop_num += self.popNum*self.susNum*(self.susNum-1)
        prop_num += self.popNum*self.hapNum*(1+1+self.sites*3+self.susNum)
        return prop_num

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void Propensities(self):
        cdef double prop

        #Migrations
        for s in range(self.popNum):
            for r in range(self.popNum):
                if s == r:
                    continue
                for i in range(self.susNum):
                    for h in range(self.hapNum):
                        self.PropensitiesMigr[s, r, i, h] = self.MigrationPropensity(s, r, i, h)


        for s in range(self.popNum):
            #Susceptibility transition
            for i in range(self.susNum):
                for j in range(self.susNum):
                    if i == j:
                        continue
                    self.PropensitiesSuscep[s, i, j] = self.suscepTransition[i, j]*self.susceptibility[h, i]

            #Infectious-realted event
            for h in range(self.hapNum):
                #Recovery
                self.PropensitiesRecovery[s, h] = self.dRate[h]*self.pm.liveBranches[s, h]

                #Sampling
                self.PropensitiesSampling[s, h] = self.sRate[h]*self.pm.liveBranches[s, h]

                #Mutation
                for site in range(self.sites):
                    for i in range(3):
                        #ht = self.Mutate(h, site, i)
                        self.PropensitiesMutatations[s, h, site, i] = self.mRate[h, site]*self.hapMutType[h, site, i]/sum(self.hapMutType[h, site])*self.pm.liveBranches[s, h]#FIXME Normalize self.hapMutType !!!
                #Transmission
                for i in range(self.susNum):
                    prop = self.bRate[h]*self.pm.contactDensity[s]
                    prop *= self.pm.migrationRates[s, s]*self.pm.migrationRates[s, s]
                    prop *= self.pm.susceptible[s, i]*self.pm.liveBranches[s, h]/self.pm.effectiveSizes[s]
                    #print(self.pm.effectiveSizes[s])
                    self.PropensitiesTransmission[s, h, i] = prop
                    #print("migr=", self.pm.migrationRates[s, s], "  prop", prop)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void GenerateEvents_tau(self, float tau, Py_ssize_t debug=0):
        cdef Py_ssize_t event_num

        #Migrations
        for s in range(self.popNum):
            for r in range(self.popNum):
                if s == r:
                    continue
                for i in range(self.susNum):
                    for h in range(self.hapNum):
                        while True:#TODO golakteko opasnoste
                            event_num = self.DrawEventsNum(self.PropensitiesMigr[s, r, i, h], tau)
                            if event_num <= self.pm.susceptible[r, i]:
                                break
                        self.eventsMigr[s, r, i, h] = event_num
                        self.pm.migPlus += event_num


        for s in range(self.popNum):
            #Susceptibility transition
            for i in range(self.susNum):
                for j in range(self.susNum):
                    if i == j:
                        continue
                    while True:#TODO golakteko opasnoste
                        event_num = self.DrawEventsNum(self.PropensitiesSuscep[s, i, j], tau)
                        if event_num <= self.pm.susceptible[s, i]:
                            break
                    self.eventsSuscep[s, i, j] = event_num
                    self.iCounter += event_num

            #Infectious-realted event
            for h in range(self.hapNum):
                #Recovery
                while True:#TODO golakteko opasnoste
                    event_num = self.DrawEventsNum(self.PropensitiesRecovery[s, h], tau)
                    if event_num <= self.pm.liveBranches[s, h]:
                        break
                self.eventsRecovery[s, h] = event_num
                self.dCounter += event_num

                #Sampling
                while True:#TODO golakteko opasnoste
                    event_num = self.DrawEventsNum(self.PropensitiesSampling[s, h], tau)
                    if event_num <= self.pm.liveBranches[s, h]:
                        break
                self.eventsSampling[s, h] = event_num
                self.sCounter += event_num

                #Mutation
                for site in range(self.sites):
                    for i in range(3):
                        while True:#TODO golakteko opasnoste
                            event_num = self.DrawEventsNum(self.PropensitiesMutatations[s, h, site, i], tau)
                            if event_num <= self.pm.liveBranches[s, h]:
                                break
                        self.eventsMutatations[s, h, site, i] = event_num
                        self.mCounter += event_num
                #Transmission
                for i in range(self.susNum):
                    while True:#TODO golakteko opasnoste
                        event_num = self.DrawEventsNum( self.PropensitiesTransmission[s, h, i], tau)
                        if event_num <= self.pm.susceptible[s, i]:
                            break
                    self.eventsTransmission[s, h, i] = event_num
                    self.bCounter += event_num

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef void UpdateCompartmentCounts_tau(self):
        cdef Py_ssize_t event_num

        #Migrations
        for s in range(self.popNum):
            for r in range(self.popNum):
                if s == r:
                    continue
                for i in range(self.susNum):
                    for h in range(self.hapNum):
                        event_num = self.eventsMigr[s, r, i, h]
                        self.pm.NewInfections(event_num, r, i, h)
                        self.multievents.AddEvents(event_num, self.currentTime, MIGRATION, h, s, i, r)


        for s in range(self.popNum):
            #Susceptibility transition
            for i in range(self.susNum):
                for j in range(self.susNum):
                    if i == j:
                        continue
                    event_num = self.eventsSuscep[s, i, j]
                    self.pm.susceptible[s, i] -= event_num
                    self.pm.susceptible[s, j] += event_num
                    self.multievents.AddEvents(event_num, self.currentTime, SUSCCHANGE, i, s, j, 0)

            #Infectious-realted event
            for h in range(self.hapNum):
                #Recovery
                event_num = self.eventsRecovery[s, h]
                self.pm.NewRecoveries(event_num, s, self.suscType[h], h)
                self.multievents.AddEvents(event_num, self.currentTime, DEATH, h, s, self.suscType[h], 0)

                #Sampling
                event_num = self.eventsSampling[s, h]
                self.pm.NewRecoveries(event_num, s, self.suscType[h], h)
                self.multievents.AddEvents(event_num, self.currentTime, SAMPLING, h, s, self.suscType[h], 0)

                #Mutation
                for site in range(self.sites):
                    for i in range(3):
                        ht = self.Mutate(h, site, i)
                        event_num = self.eventsMutatations[s, h, site, i]
                        self.pm.liveBranches[s, ht] += event_num
                        self.pm.liveBranches[s, h] -= event_num
                        self.multievents.AddEvents(event_num, self.currentTime, MUTATION, h, s, ht, 0)
                #Transmission
                for i in range(self.susNum):
                    event_num = self.eventsTransmission[s, h, i]
                    self.pm.NewInfections(event_num, s, i, h)
                    self.multievents.AddEvents(event_num, self.currentTime, BIRTH, h, s, i, 0)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef inline Py_ssize_t DrawEventsNum(self, prop, tau):
        cdef Py_ssize_t n
        n = np.random.poisson(prop*tau)
        #print(n)
        return n

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cdef void ChooseTau(self, float epsilon=0.03):
        cdef float tmp
        self.infectiousAuxTau = np.zeros((self.popNum, self.hapNum, 2), dtype=float)
        self.susceptibleAuxTau = np.zeros((self.popNum, self.susNum, 2), dtype=float)
        #Migrations
        for s in range(self.popNum):
            for r in range(self.popNum):
                if s == r:
                    continue
                for i in range(self.susNum):
                    for h in range(self.hapNum):
                        self.infectiousAuxTau[r, h, 0] += self.PropensitiesMigr[s, r, i, h]
                        self.susceptibleAuxTau[r, i, 0] -= self.PropensitiesMigr[s, r, i, h]

        for s in range(self.popNum):
            #Susceptibility transition
            for i in range(self.susNum):
                for j in range(self.susNum):
                    if i == j:
                        continue
                    self.susceptibleAuxTau[s, i, 0] -= self.PropensitiesSuscep[s, i, j]
                    self.susceptibleAuxTau[s, j, 0] += self.PropensitiesSuscep[s, i, j]

            #Infectious-realted event
            for h in range(self.hapNum):
                #Recovery
                self.infectiousAuxTau[s, h, 0] -= self.PropensitiesRecovery[s, h]
                self.susceptibleAuxTau[r, self.suscType[h], 0] += self.PropensitiesRecovery[s, h]

                #Sampling
                self.infectiousAuxTau[s, h, 0] -= self.PropensitiesSampling[s, h]
                self.susceptibleAuxTau[r, self.suscType[h], 0] += self.PropensitiesSampling[s, h]
                #Mutation
                for site in range(self.sites):
                    for i in range(3):
                        ht = self.Mutate(h, site, i)
                        self.infectiousAuxTau[s, h, 0] -= self.PropensitiesMutatations[s, h, site, i]
                        self.infectiousAuxTau[s, ht, 0] += self.PropensitiesMutatations[s, h, site, i]
                #Transmission
                for i in range(self.susNum):
                    self.infectiousAuxTau[s, h, 0] += self.PropensitiesTransmission[s, h, i]
                    self.susceptibleAuxTau[s, i, 0] -= self.PropensitiesTransmission[s, h, i]
                    #print("migr=", self.pm.migrationRates[s, s], "  prop", prop)
        self.tau_l = 1.0
        for s in range(self.popNum):
            for h in range(self.hapNum):
                if abs(self.infectiousAuxTau[s, h, 0]) < 1e-8:
                    continue
                tmp = max(epsilon*self.pm.liveBranches[s,h]/2.0,1.0)/abs(self.infectiousAuxTau[s, h, 0])
                if tmp < self.tau_l:
                    self.tau_l = tmp
            for i in range(self.susNum):
                if abs(self.susceptibleAuxTau[s, h, 0]) < 1e-8:
                    continue
                tmp = max(epsilon*self.pm.susceptible[s,i]/2.0,1.0)/abs(self.susceptibleAuxTau[s, i, 0])
                if tmp < self.tau_l:
                    self.tau_l = tmp

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.cdivision(True)
    cdef Py_ssize_t Mutate(self, Py_ssize_t h, Py_ssize_t site, Py_ssize_t DS):
        cdef:
            Py_ssize_t mi, digit4, AS
        digit4 = 4**site
        AS = int(floor(h/digit4) % 4)
        if DS >= AS:
            DS += 1
        return h + (DS-AS)*digit4

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef void SimulatePopulation_tau(self, Py_ssize_t iterations, Py_ssize_t sampleSize=-1, float time=-1):
        cdef Py_ssize_t pi, propNum
        propNum = self.PropensitiesNumber()
        if self.first_simulation == False:
            self.pm.FirstInfection()
            self.first_simulation = True
        self.multievents.CreateEvents(iterations*propNum)
        for i in range(self.popNum):
            self.pm.migrationRates[i, i] = 1.0
            for j in range(self.popNum):
                if i==j:
                    continue
                self.pm.migrationRates[i, i] -= self.pm.migrationRates[i, j]
        #self.totalLen = 0.0
        while (self.multievents.ptr<self.multievents.size and (sampleSize==-1 or self.sCounter<sampleSize) and (time==-1 or self.currentTime<time)):
            self.Propensities()
            self.ChooseTau()
            #print(self.tau_l)
            self.currentTime += self.tau_l
            self.GenerateEvents_tau(self.tau_l)
            self.UpdateCompartmentCounts_tau()
            if self.pm.globalInfectious == 0:
                break
            for s in range(self.popNum):
                self.CheckLockdown(s)
        print("Number of iterations: ", int(self.multievents.ptr/propNum))
        print("Simulation model time: ", self.currentTime)


    @cython.boundscheck(False)
    @cython.wraparound(False)
    def Get_MultiEvents(self, id = None):
        if id is None:
            for i in range(self.multievents.ptr):
                ev = self.multievents.GetEvent(i)
                ev.PrintEvent()
        else:
            ev = self.multievents.GetEvent(id)
            ev.PrintEvent()



    def PrintCounters(self):
        print("Birth counter(mutable): ", self.bCounter)
        print("Death counter(mutable): ", self.dCounter)
        print("Sampling counter(mutable): ", self.sCounter)
        print("Mutation counter(mutable): ", self.mCounter)
        print("Immunity transition counter(mutable):", self.iCounter)
        print("Migration counter(mutable):", self.pm.migPlus)
