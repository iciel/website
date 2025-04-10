import React, { useEffect, useState, useCallback } from 'react'
import { Request, usePaginatedRequestQuery } from '../../hooks/request-query'
import { useList } from '../../hooks/use-list'
import { useHistory, removeEmpty } from '../../hooks/use-history'
import { CommunitySolution as CommunitySolutionProps } from '../types'
import { CommunitySolution } from '../common/CommunitySolution'
import { Pagination } from '../common'
import { FetchingBoundary } from '../FetchingBoundary'
import { ResultsZone } from '../ResultsZone'
import { TrackDropdown } from './community-solutions-list/TrackDropdown'
import { OrderSelect } from './community-solutions-list/OrderSelect'

export type TrackData = {
  iconUrl: string
  title: string
  slug: string | null
  numSolutions: number
}

type PaginatedResult = {
  results: CommunitySolutionProps[]
  meta: {
    currentPage: number
    totalCount: number
    totalPages: number
    unscopedTotal: number
  }
}

export type Order = 'most_starred' | 'newest_first' | 'oldest_first'

const DEFAULT_ERROR = new Error('Unable to pull solutions')
const DEFAULT_ORDER = 'most_starred'

export const CommunitySolutionsList = ({
  request: initialRequest,
  tracks,
}: {
  request: Request
  tracks: TrackData[]
}): JSX.Element => {
  const {
    request,
    setCriteria: setRequestCriteria,
    setPage,
    setOrder,
    setQuery,
  } = useList(initialRequest)
  const [criteria, setCriteria] = useState(request.query?.criteria || '')
  const {
    status,
    resolvedData,
    latestData,
    isFetching,
    error,
  } = usePaginatedRequestQuery<PaginatedResult, Error | Response>(
    ['profile-community-solution-list', request.endpoint, request.query],
    request
  )

  const setTrack = useCallback(
    (slug) => {
      setQuery({ ...request.query, trackSlug: slug, page: undefined })
    },
    [request.query, setQuery]
  )

  useEffect(() => {
    const handler = setTimeout(() => {
      setRequestCriteria(criteria)
    }, 200)

    return () => {
      clearTimeout(handler)
    }
  }, [setRequestCriteria, criteria])

  useHistory({ pushOn: removeEmpty(request.query) })

  return (
    <div className="lg-container">
      <div className="c-search-bar">
        <TrackDropdown
          tracks={tracks}
          value={request.query.trackSlug || null}
          setValue={setTrack}
        />
        <input
          className="--search"
          onChange={(e) => {
            setCriteria(e.target.value)
          }}
          value={criteria}
          placeholder="Filter by exercise"
        />
        <OrderSelect
          value={request.query.order || DEFAULT_ORDER}
          setValue={setOrder}
        />
      </div>
      <ResultsZone isFetching={isFetching}>
        <FetchingBoundary
          status={status}
          error={error}
          defaultError={DEFAULT_ERROR}
        >
          {resolvedData ? (
            <React.Fragment>
              <div className="solutions">
                {resolvedData.results.map((solution) => {
                  return (
                    <CommunitySolution
                      key={solution.uuid}
                      solution={solution}
                      context="profile"
                    />
                  )
                })}
              </div>
              <Pagination
                disabled={latestData === undefined}
                current={request.query.page}
                total={resolvedData.meta.totalPages}
                setPage={setPage}
              />
            </React.Fragment>
          ) : null}
        </FetchingBoundary>
      </ResultsZone>
    </div>
  )
}
